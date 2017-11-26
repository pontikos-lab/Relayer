require 'English'
require 'forwardable'
require 'json'

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
      def run(params, user)
        init(params, user)
        run_matlab
        Thread.new { compress_output_dir(@run_dir, @run_out_dir) }
        { uniq_run: @uniq_time, exit_code: @matlab_exit_code }
      end

      private

      # sets up analysis
      def init(params, user)
        @params = params
        @user = user
        @files = JSON.parse(@params[:files], symbolize_names: true)

        assert_params
        @uniq_time = Time.new.strftime('%Y-%m-%d_%H-%M-%S_%L-%N').to_s
        setup_run_dir
      end

      def assert_params
        return if assert_param_exist && assert_files && assert_files_exists
        raise ArgumentError, 'Failed to upload files'
      end

      def assert_param_exist
        !@params.nil?
      end

      def assert_files
        @files.collect { |f| f[:status] == 'upload successful' }.uniq
      end

      def assert_files_exists
        r = @files.collect do |f|
          puts f
          File.exist?(File.join(tmp_dir, f[:uuid], f[:originalName]))
        end
        r.uniq
      end

      def setup_run_dir
        @run_dir = File.join(users_dir, @user, @uniq_time)
        @run_out_dir = File.join(@run_dir, 'out')
        @run_files_dir = File.join(@run_dir, 'files')
        logger.debug("Creating Run Directory: #{@run_dir}")
        FileUtils.mkdir_p(@run_files_dir)
        FileUtils.mkdir_p(@run_out_dir)
        move_uploaded_files_into_run_dir
        dump_params_to_file
      end

      def move_uploaded_files_into_run_dir
        @files.each do |f|
          t_dir = File.join(tmp_dir, f[:uuid])
          t_input_file = File.join(t_dir, f[:originalName])
          f = File.join(@run_files_dir, f[:originalName])
          FileUtils.mv(t_input_file, f)
          next unless (Dir.entries(t_dir) - %w[. ..]).empty?
          FileUtils.rm_r(t_dir)
        end
      end

      def dump_params_to_file
        params_file = File.join(@run_dir, 'params.json')
        File.open(params_file, 'w') { |io| io.puts @params.to_json }
      end

      def run_matlab
        input_file = file_names
        logger.debug("Running CMD: #{matlab_cmd(input_file)}")
        system(matlab_cmd(input_file))
        @matlab_exit_code = $CHILD_STATUS.exitstatus
        logger.debug("Matlab CMD Exit Code: #{@matlab_exit_code}")
      end

      def file_names
        fnames = @files.collect { |f| f[:originalName] }
        return File.join(@run_files_dir, fnames[0]) if fnames.length == 1
        @run_files_dir
      end

      # processVolumeRELAYER(octVolume, machineCode, folder, verbose)
      def matlab_cmd(input_file)
        "#{config[:matlab_bin]} -nodisplay -nosplash -r \" " \
        "addpath(genpath('#{config[:oct_library_path]}'));" \
        "[octVolume, ~] = readOCTvolumeMEH('#{input_file}');" \
        '[~,~,~,thickness] = processVolumeRELAYER(octVolume,'\
        " #{@params['machine_type']}, '#{@run_out_dir}');" \
        "fileID = fopen('#{File.join(@run_out_dir, 'thickness.json')}','w');" \
        'fprintf(fileID, jsonencode(round(thickness, 2)));' \
        'fclose(fileID);' \
        'exit;"'
      end

      def compress_output_dir(run_dir, run_out_dir)
        cmd = "zip -jr '#{run_dir}/relayer_results.zip' '#{run_out_dir}'"
        logger.debug("Running CMD: #{cmd}")
        system(cmd)
      end
    end
  end
end
