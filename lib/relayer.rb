require 'fileutils'
require 'json'
require 'yaml'

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
    # We don't validate port and host settings. If Relayer is run
    # self-hosted, bind will fail on incorrect values. If Relayer
    # is run via Apache/Nginx + Passenger, we don't need to worry.
    def init(config = {})
      @config = Config.new(config)
      Thread.abort_on_exception = true if verbose?

      init_dirs
      check_num_threads
      init_colour_map

      self
    end

    # default relayer_dir = $HOME/.relayer/
    # default public_dir  = $HOME/.relayer/public/
    # default users_dir   = $HOME/.relayer/users/
    # default tmp_dir     = $HOME/.relayer/tmp/
    attr_reader :config, :relayer_dir, :public_dir, :users_dir,
                :tmp_dir, :colour_map

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
      puts "   Go to #{server_url} in your browser & start analysing OCT Scans!"
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

    # Run Relayer interactively
    def pry
      # rubocop:disable Lint/Debugger
      ARGV.clear
      require 'pry'
      binding.pry
      # rubocop:enable Lint/Debugger
    end

    private

    # Set up the directory structure in @config[:gd_public_dir]
    def init_dirs
      config[:relayer_dir] = File.expand_path(config[:relayer_dir])
      logger.debug "Relayer Directory: #{config[:relayer_dir]}"
      init_public_dir
      init_public_data_dirs
      init_tmp_dir
      init_users_dir
      set_up_default_user_dir
    end

    def init_public_dir
      @public_dir = File.join(config[:relayer_dir], 'public')
      logger.debug "public_dir Directory: #{@public_dir}"
      FileUtils.mkdir_p @public_dir unless Dir.exist?(@public_dir)
      root_assets = File.join(Relayer.root, 'public/assets')
      assets = File.join(@public_dir, 'assets')
      css = File.join(assets, 'css', "style-#{Relayer::VERSION}.min.css")
      init_assets(root_assets, assets, css)
    end

    def init_assets(root_assets, assets, css)
      if environment == 'development'
        FileUtils.rm_rf(assets) unless File.symlink?(assets)
        FileUtils.ln_s(root_assets, @public_dir) unless File.exist?(assets)
      else
        FileUtils.rm_rf(assets) if File.symlink?(assets) || !File.exist?(css)
        FileUtils.cp_r(root_assets, @public_dir) unless File.exist?(assets)
      end
    end

    def init_public_data_dirs
      root_data = File.join(Relayer.root, 'public/relayer')
      public_gd = File.join(@public_dir, 'relayer')
      return if File.exist?(public_gd)
      FileUtils.cp_r(root_data, @public_dir)
    end

    def init_tmp_dir
      @tmp_dir = File.join(config[:relayer_dir], 'tmp')
      logger.debug "tmp_dir Directory: #{@tmp_dir}"
      FileUtils.mkdir_p @tmp_dir unless Dir.exist? @tmp_dir
    end

    def init_users_dir
      @users_dir = File.join(config[:relayer_dir], 'users')
      logger.debug "users_dir Directory: #{@users_dir}"
      FileUtils.mkdir_p @users_dir unless Dir.exist? @users_dir
    end

    def set_up_default_user_dir
      user_dir    = File.join(Relayer.users_dir, 'relayer')
      user_public = File.join(Relayer.public_dir, 'relayer/users')
      FileUtils.mkdir(user_dir) unless Dir.exist?(user_dir)
      return if File.exist? File.join(user_public, 'relayer')
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

    def server_url(initial_page = 'oct_segmentation')
      host = config[:host]
      host = 'localhost' if ['127.0.0.1', '0.0.0.0'].include? host
      "http://#{host}:#{config[:port]}/#{initial_page}"
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

    def init_colour_map
      file = IO.read(File.join(@public_dir, 'assets/colourMap.json'))
      @colour_map = JSON.parse(file)
    end
  end
end
