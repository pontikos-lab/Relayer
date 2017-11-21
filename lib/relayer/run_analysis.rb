require 'English'
require 'forwardable'

require 'relayer/pool'

# Relayer NameSpace
module Relayer
  # Module to run the OCT Segmentation analysis
  module RelayerAnalysis
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

      def_delegators Relayer, :config, :logger, :relayer_dir,
                     :public_dir, :users_dir, :tmp_dir

      # Runs the matlab analysis
      def run(params, file_params, user)
        @params = params
        init(file_params, user)
        run_matlab
        { run_dir: @uniq_time, exit_code: @matlab_exit_code }
      end

      private

      # sets up analysis
      def init(file_params, user)
        @file_params = file_params
        @user = user
        raise ArgumentError, 'Failed to upload files' unless assert_params
        @uniq_time = Time.new.strftime('%Y-%m-%d_%H-%M-%S_%L-%N').to_s
        setup_run_dir
      end

      def assert_params
        assert_param_exist && assert_upload_status && assert_file_exists
      end

      def assert_param_exist
        !@file_params.nil?
      end

      def assert_upload_status
        @file_params[:status] == 'upload successful'
      end

      def assert_file_exists
        @tmp_input = File.join(tmp_dir, @file_params[:uuid],
                               @file_params[:originalName])
        File.exist?(@tmp_input)
      end

      def setup_run_dir
        @run_dir = File.join(users_dir, @user, @uniq_time)
        logger.debug("Creating Run Directory: #{@run_dir}")
        FileUtils.mkdir_p(@run_dir)
        @input_file = File.join(@run_dir, @file_params[:originalName])
        FileUtils.mv(@tmp_input, @input_file)
        dump_params_to_file
      end

      def dump_params_to_file
        File.open(File.join(@run_dir, 'params.json'), 'w') do |io|
          io.puts @params.to_json
        end
      end

      def run_matlab
        logger.debug("Running CMD: #{matlab_cmd(@input_file)}")
        system(matlab_cmd(@input_file))
        @matlab_exit_code = $CHILD_STATUS.exitstatus
        logger.debug(@matlab_exit_code)
      end

      # processVolumeRELAYER(octVolume, machineCode, folder, verbose)
      def matlab_cmd(input_file)
        "#{config[:matlab_bin]} -nodisplay -nosplash -r \" " \
        "addpath(genpath('#{config[:oct_library_path]}'));" \
        "[octVolume, ~] = readOCTvolumeMEH('#{input_file}');" \
        '[~,~,~,thickness] = processVolumeRELAYER(octVolume,'\
        " #{@params['machine_type']}, '#{@run_dir}');" \
        "fileID = fopen('#{File.join(@run_dir, 'thickness.json')}','w');" \
        'fprintf(fileID, jsonencode(round(thickness, 2)));' \
        'fclose(fileID);' \
        'exit;"'
      end
    end
  end
end
