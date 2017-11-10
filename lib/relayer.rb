require 'yaml'
require 'fileutils'

require 'relayer/config'
require 'relayer/exceptions'
require 'relayer/logger'
require 'relayer/routes'
require 'relayer/run_analysis'
require 'relayer/server'
require 'relayer/version'

# Relayer NameSpace
module Relayer
  class << self
    def environment
      ENV['RACK_ENV']
    end

    def verbose?
      @verbose ||= (environment == 'development')
    end

    def root
      File.dirname(File.dirname(__FILE__))
    end

    def ssl?
      @config[:ssl]
    end

    def logger
      @logger ||= Logger.new(STDOUT)
    end

    # Setting up the environment before running the app...
    def init(config = {})
      @config = Config.new(config)

      init_dirs
      logger.debug "Relayer Directory: #{config[:relayer_dir]}"
      logger.debug "public_dir Directory: #{public_dir}"
      logger.debug "users_dir Directory: #{users_dir}"
      logger.debug "tmp_dir Directory: #{tmp_dir}"

      set_up_default_user_dir
      check_num_threads

      self

      # We don't validate port and host settings. If Relayer is run
      # self-hosted, bind will fail on incorrect values. If Relayer
      # is run via Apache/Nginx + Passenger, we don't need to worry.
    end

    # relayer_dir = $HOME/.relayer/
    # public_dir  = $HOME/.relayer/public/
    # users_dir   = $HOME/.relayer/users/
    # tmp_dir     = $HOME/.relayer/tmp/
    attr_reader :config, :relayer_dir, :public_dir, :users_dir,
                :tmp_dir

    # Starting the app manually
    def run
      check_host
      Server.run(self)
    rescue Errno::EADDRINUSE
      puts "** Could not bind to port #{config[:port]}."
      puts "   Is Relayer already accessible at #{server_url}?"
      puts '   No? Try running Relayer on another port, like so:'
      puts
      puts '       relayer -p 4570.'
    rescue Errno::EACCES
      puts "** Need root privilege to bind to port #{config[:port]}."
      puts '   It is not advisable to run Relayer as root.'
      puts '   Please use Apache/Nginx to bind to a privileged port.'
    end

    def on_start
      puts '** Relayer is ready.'
      puts "   Go to #{server_url} in your browser and start analysing GEO datasets!"
      puts '   Press CTRL+C to quit.'
      open_in_browser(server_url)
    end

    def on_stop
      puts
      puts '** Thank you for using Relayer :).'
    end

    # Rack-interface.
    #
    # Inject our logger in the env and dispatch request to our controller.
    def call(env)
      env['rack.logger'] = logger
      Routes.call(env)
    end

    private

    # Set up the directory structure in @config[:gd_public_dir]
    def init_dirs
      config[:relayer_dir] = File.expand_path config[:relayer_dir]
      @public_dir = File.join(config[:relayer_dir], 'public')
      @users_dir  = File.expand_path('../users', @public_dir)
      @tmp_dir    =  File.expand_path('../tmp', @public_dir)
      init_public_dir
      FileUtils.mkdir_p @users_dir unless Dir.exist? @users_dir
      FileUtils.mkdir_p @tmp_dir unless Dir.exist? @tmp_dir
    end

    # Create the public dir, if already created and the right CSS/JS version do
    # not exist then remove the existing assets and copy over the new assets
    def init_public_dir
      root_assets = File.join(Relayer.root, 'public/assets')
      root_data = File.join(Relayer.root, 'public/Relayer')
      if Dir.exist?(@public_dir)
        FileUtils.rm_r File.join(@public_dir, 'assets')
      else
        FileUtils.mkdir_p @public_dir
        FileUtils.cp_r(root_data, @public_dir)
      end
      if environment == 'development'
        FileUtils.ln_s(root_assets, @public_dir)
      else
        FileUtils.cp_r(root_assets, @public_dir)
      end
    end

    def set_up_default_user_dir
      user_dir    = File.join(Relayer.users_dir, 'Relayer')
      user_public = File.join(Relayer.public_dir, 'Relayer/users')
      FileUtils.mkdir(user_dir) unless Dir.exist?(user_dir)
      return if File.exist? File.join(user_public, 'Relayer')
      FileUtils.ln_s(user_dir, user_public)
    end

    def check_num_threads
      config[:num_threads] = Integer(config[:num_threads])
      raise NUM_THREADS_INCORRECT unless config[:num_threads] > 0

      logger.debug "Will use #{config[:num_threads]} threads to run Relayer."
      return unless config[:num_threads] > 256
      logger.warn "Number of threads set at #{config[:num_threads]} is" \
                  ' unusually high.'
    end

    # Check and warn user if host is 0.0.0.0 (default).
    def check_host
      return unless config[:host] == '0.0.0.0'
      logger.warn 'Will listen on all interfaces (0.0.0.0).' \
                  ' Consider using 127.0.0.1 (--host option).'
    end

    def server_url
      host = config[:host]
      host = 'localhost' if host == '127.0.0.1' || host == '0.0.0.0'
      "http://#{host}:#{config[:port]}/analyse"
    end

    def open_in_browser(server_url)
      return if using_ssh? || verbose?
      if RUBY_PLATFORM =~ /linux/ && xdg?
        system "xdg-open #{server_url}"
      elsif RUBY_PLATFORM =~ /darwin/
        system "open #{server_url}"
      end
    end

    def using_ssh?
      true if ENV['SSH_CLIENT'] || ENV['SSH_TTY'] || ENV['SSH_CONNECTION']
    end

    def xdg?
      true if ENV['DISPLAY'] && system('which xdg-open > /dev/null 2>&1')
    end
  end
end
