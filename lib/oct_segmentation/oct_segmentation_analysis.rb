require 'English'
require 'forwardable'

require 'oct_segmentation/pool'

# OctSegmentation NameSpace
module OctSegmentation
  # Module to run the OCT Segmentation analysis
  module OctSegmentationAnalysis
    # To signal error in parameters provided.
    #
    # ArgumentError is raised when When the file the
    class ArgumentError < ArgumentError
    end

    # To signal internal errors.
    #
    # RuntimeError is raised when there is a problem in running matlab Script,
    # writing the output etc. These are rare, infrastructure errors, used
    # internally, and of concern only to the admins/developers.
    # One example of a RuntimeError would be matlab not installed.
    class RuntimeError < RuntimeError
    end

    class << self
      extend Forwardable

      def_delegators OctSegmentation, :config, :logger, :oct_segmentation_dir,
                     :public_dir, :users_dir, :tmp_dir

      # Runs the matlab analysis
      def run(params, user)
        init(params, user)
        run_matlab
      end

      private

      # sets up analysis
      def init(params, user)
        @params = params
        @user = user
        raise ArgumentError, "Failed to upload files" unless assert_params
        @uniq_time = Time.new.strftime('%Y-%m-%d_%H-%M-%S_%L-%N').to_s
        setup_run_dir
      end

      def assert_params
        assert_param_exist && assert_upload_status && assert_file_exists
      end

      def assert_param_exist
        !@params.nil?
      end

      def assert_upload_status
        @params[:status] == 'upload successful'
      end

      def assert_file_exists
        @tmp_input = File.join(tmp_dir, @params[:uuid], @params[:originalName])
        File.exist?(@tmp_input)
      end

      def setup_run_dir
        @run_dir = File.join(users_dir, @user, @uniq_time)
        logger.debug("Creating Run Directory: #{@run_dir}")
        FileUtils.mkdir_p(@run_dir)
        @input = File.join(@run_dir, @params[:originalName])
        FileUtils.mv(@tmp_input, @input)
        dump_params_to_file
      end

      def dump_params_to_file
        File.open(File.join(@run_dir, 'params.json'), "w") do |io|
          io.puts @params.to_json
        end
      end

      def run_matlab
        sleep(10)
      end
    end
  end
end
