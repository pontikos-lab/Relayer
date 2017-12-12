require 'English'
require 'forwardable'
require 'json'

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
                     :public_dir, :users_dir, :tmp_dir, :colour_map

      # Runs the matlab analysis
      def run(params, user, url)
        init(params, user)
        run_matlab
        if @matlab_exit_code.zero?
          Thread.new { compress_output_dir(@run_dir, @run_out_dir) }
        end
        write_results_to_file(url)
        { exit_code: @matlab_exit_code, scale: @colour_scale,
          assets_path: "#{url}/relayer/users/#{@email}/#{@uniq_time}",
          results_url: "#{url}/result/#{encode_email}/#{@uniq_time}",
          share_url: "#{url}/sh/#{encode_email}/#{@uniq_time}",
          uuid: @uniq_time }
      end

      private

      # sets up analysis
      def init(params, user)
        @params = params
        @email = user
        @params[:files] = JSON.parse(@params[:files], symbolize_names: true)
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
        @params[:files].collect { |f| f[:status] == 'upload successful' }.uniq
      end

      def assert_files_exists
        files = @params[:files].collect do |f|
          File.exist?(File.join(tmp_dir, f[:uuid], f[:originalName]))
        end
        files.uniq
      end

      def setup_run_dir
        @run_dir = File.join(users_dir, @email, @uniq_time)
        @run_out_dir = File.join(@run_dir, 'out')
        @run_files_dir = File.join(@run_dir, 'files')
        logger.debug("Creating Run Directory: #{@run_dir}")
        FileUtils.mkdir_p(@run_files_dir)
        FileUtils.mkdir_p(@run_out_dir)
        move_uploaded_files_into_run_dir
      end

      def move_uploaded_files_into_run_dir
        @params[:files].each do |f|
          t_dir = File.join(tmp_dir, f[:uuid])
          t_input_file = File.join(t_dir, f[:originalName])
          f = File.join(@run_files_dir, f[:originalName])
          FileUtils.mv(t_input_file, f)
          next unless (Dir.entries(t_dir) - %w[. ..]).empty?
          FileUtils.rm_r(t_dir)
        end
      end

      def run_matlab
        input_file = file_names
        logger.debug("Running CMD: #{matlab_cmd(input_file)}")
        system(matlab_cmd(input_file))
        @matlab_exit_code = $CHILD_STATUS.exitstatus
        logger.debug("Matlab CMD Exit Code: #{@matlab_exit_code}")
        @colour_scale = generate_colour_scale
      end

      def file_names
        fnames = @params[:files].collect { |f| f[:originalName] }
        return File.join(@run_files_dir, fnames[0]) if fnames.length == 1
        @run_files_dir
      end

      def matlab_cmd(input)
        generate_matlab_script(input)
        "#{config[:matlab_bin]} -nodisplay -nosplash -nodesktop -r analysis" \
        " -sd '#{@run_out_dir}'"
      end

      def generate_matlab_script(input)
        File.open(File.join(@run_out_dir, 'analysis.m'), 'w') do |io|
          thickness_json = File.join(@run_out_dir, 'thickness.json')
          matlab_code(io, input, thickness_json)
        end
      end

      # processVolumeRELAYER(octVolume, machineCode, folder, verbose)
      def matlab_code(io, input, thickness_json)
        io.puts "addpath(genpath('#{config[:oct_library_path]}'));"
        io.puts "[~,~,~,thickness] = processVolumeRELAYER('#{input}',"\
                " #{@params['machine_type']}, '#{@run_out_dir}');"
        io.puts "fileID = fopen('#{thickness_json}','w');"
        io.puts 'fprintf(fileID, jsonencode(round(thickness, 2)));'
        io.puts 'fclose(fileID);'
        io.puts 'exit;'
      end

      def compress_output_dir(run_dir, run_out_dir)
        cmd = "zip -jr '#{run_dir}/relayer_results.zip' '#{run_out_dir}'"
        logger.debug("Running CMD: #{cmd}")
        system(cmd)
      end

      def generate_colour_scale
        return [] unless File.exist? File.join(@run_out_dir, 'thickness.json')
        data = JSON.parse(IO.read(File.join(@run_out_dir, 'thickness.json')))
        values = quartiles(data)
        [
          ['0', raw_val_to_colour(values[0])],
          ['0.25', raw_val_to_colour(values[1])],
          ['0.5', raw_val_to_colour(values[2])],
          ['0.75', raw_val_to_colour(values[3])],
          ['1', raw_val_to_colour(values[4])]
        ]
      end

      def quartiles(data)
        max = data.flatten!.max
        min = data.min
        q2 = ((min + max) / 2)
        q1 = ((min + q2) / 2)
        q3 = ((max + q2) / 2)
        [min, q1, q2, q3, max]
      end

      def raw_val_to_colour(val)
        v = val.round
        'rgb(' + colour_map[v] + ')'
      end

      def write_results_to_file(url)
        results = generate_results_hash(url)
        params_file = File.join(@run_dir, 'params.json')
        File.open(params_file, 'w') { |io| io.puts results.to_json }
      end

      def generate_results_hash(url)
        {
          params: @params,
          user: encode_email,
          results_url: "#{url}/result/#{encode_email}/#{@uniq_time}",
          share_url: "#{url}/sh/#{encode_email}/#{@uniq_time}",
          assets_path: "#{url}/relayer/users/#{@email}/#{@uniq_time}",
          full_path: @run_dir,
          uniq_result_id: @uniq_time,
          exit_code: @matlab_exit_code,
          scale: @colour_scale
        }
      end

      def encode_email
        Base64.encode64(@email).chomp
      end
    end
  end
end
