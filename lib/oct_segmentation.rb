require 'yaml'
require 'fileutils'

require 'oct_segmentation/config'
require 'oct_segmentation/exceptions'
require 'oct_segmentation/logger'
require 'oct_segmentation/routes'
require 'oct_segmentation/oct_segmentation_analysis'
require 'oct_segmentation/server'
require 'oct_segmentation/version'

# OctSegmentation NameSpace
module OctSegmentation
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
      logger.debug "OctSegmentation Directory: #{config[:oct_segmentation_dir]}"
      logger.debug "public_dir Directory: #{public_dir}"
      logger.debug "users_dir Directory: #{users_dir}"
      logger.debug "tmp_dir Directory: #{tmp_dir}"

      set_up_default_user_dir
      check_num_threads

      self

      # We don't validate port and host settings. If OctSegmentation is run
      # self-hosted, bind will fail on incorrect values. If OctSegmentation
      # is run via Apache/Nginx + Passenger, we don't need to worry.
    end

    # oct_segmentation_dir = $HOME/.oct_segmentation/
    # public_dir           = $HOME/.oct_segmentation/public/
    # users_dir            = $HOME/.oct_segmentation/users/
    # tmp_dir              = $HOME/.oct_segmentation/tmp/
    attr_reader :config, :oct_segmentation_dir, :public_dir, :users_dir,
                :tmp_dir

    # Starting the app manually
    def run
      check_host
      Server.run(self)
    rescue Errno::EADDRINUSE
      puts "** Could not bind to port #{config[:port]}."
      puts "   Is OctSegmentation already accessible at #{server_url}?"
      puts '   No? Try running OctSegmentation on another port, like so:'
      puts
      puts '       oct_segmentation -p 4570.'
    rescue Errno::EACCES
      puts "** Need root privilege to bind to port #{config[:port]}."
      puts '   It is not advisable to run OctSegmentation as root.'
      puts '   Please use Apache/Nginx to bind to a privileged port.'
    end

    def on_start
      puts '** OctSegmentation is ready.'
      puts "   Go to #{server_url} in your browser and start analysing GEO datasets!"
      puts '   Press CTRL+C to quit.'
      open_in_browser(server_url)
    end

    def on_stop
      puts
      puts '** Thank you for using OctSegmentation :).'
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
      config[:oct_segmentation_dir] = File.expand_path config[:oct_segmentation_dir]
      @public_dir = File.join(config[:oct_segmentation_dir], 'public')
      @users_dir  = File.expand_path('../users', @public_dir)
      @tmp_dir    =  File.expand_path('../tmp', @public_dir)
      init_public_dir
      FileUtils.mkdir_p @users_dir unless Dir.exist? @users_dir
      FileUtils.mkdir_p @tmp_dir unless Dir.exist? @tmp_dir
    end

    # Create the public dir, if already created and the right CSS/JS version do
    # not exist then remove the existing assets and copy over the new assets
    def init_public_dir
      root_assets = File.join(OctSegmentation.root, 'public/assets')
      root_data = File.join(OctSegmentation.root, 'public/OctSegmentation')
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
      user_dir    = File.join(OctSegmentation.users_dir, 'OctSegmentation')
      user_public = File.join(OctSegmentation.public_dir, 'OctSegmentation/users')
      FileUtils.mkdir(user_dir) unless Dir.exist?(user_dir)
      return if File.exist? File.join(user_public, 'OctSegmentation')
      FileUtils.ln_s(user_dir, user_public)
    end

    def check_num_threads
      config[:num_threads] = Integer(config[:num_threads])
      raise NUM_THREADS_INCORRECT unless config[:num_threads] > 0

      logger.debug "Will use #{config[:num_threads]} threads to run OctSegmentation."
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
      "http://#{host}:#{config[:port]}"
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
