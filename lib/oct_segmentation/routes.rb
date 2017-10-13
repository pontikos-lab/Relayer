require 'base64'
require 'json'
require 'omniauth'
require 'omniauth-google-oauth2'
require 'sinatra/base'
require 'slim'

require 'oct_segmentation/version'

module OctSegmentation
  # Sinatra Routes - i.e. The Controller
  class Routes < Sinatra::Base
    # See http://www.sinatrarb.com/configuration.html
    configure do
      # We don't need Rack::MethodOverride. Let's avoid the overhead.
      disable :method_override

      # Ensure exceptions never leak out of the app. Exceptions raised within
      # the app must be handled by the app. We do this by attaching error
      # blocks to exceptions we know how to handle and attaching to Exception
      # as fallback.
      disable :show_exceptions, :raise_errors

      # Make it a policy to dump to 'rack.errors' any exception raised by the
      # app so that error handlers don't have to do it themselves. But for it
      # to always work, Exceptions defined by us should not respond to `code`
      # or http_status` methods. Error blocks errors must explicitly set http
      # status, if needed, by calling `status` method.
      enable :dump_errors

      # We don't want Sinatra do setup any loggers for us. We will use our own.
      set :logging, nil

      # Use Rack::Session::Pool over Sinatra default sessions.
      use Rack::Session::Pool, expire_after: 2_592_000 # 30 days

      # view directory will be found here.
      set :root, -> { OctSegmentation.root }

      # This is the full path to the public folder...
      set :public_folder, -> { OctSegmentation.public_dir }
    end

    helpers do
      # Overide default URI helper method - to hardcode a https://
      # In our setup, we are running passenger on http:// (not secure) and then
      # reverse proxying that onto a 443 port (i.e. https://)
      # Generates the absolute URI for a given path in the app.
      # Takes Rack routers and reverse proxies into account.
      def uri(addr = nil, absolute = true, add_script_name = true)
        return addr if addr =~ /\A[a-z][a-z0-9\+\.\-]*:/i
        uri = [host = String.new]
        if absolute
          host << (OctSegmentation.ssl? ? "https://" : "http://")
          if request.forwarded? or request.port != (request.secure? ? 443 : 80)
            host << request.host_with_port
          else
            host << request.host
          end
        end
        uri << request.script_name.to_s if add_script_name
        uri << (addr ? addr : request.path_info).to_s
        File.join uri
      end

      def base_url
        proxy = OctSegmentation.ssl? ? 'https' : 'http'
        @base_url ||= "#{proxy}://#{request.env['HTTP_HOST']}"
      end
    end

    # For any request that hits the app, log incoming params at debug level.
    before do
      logger.debug params
    end

    # Home page (marketing page)
    get '/' do
      slim :index, layout: false
    end

    # Run the OctSegmentation Analysis
    post '/analyse' do
      slim :results, layout: false
    end

    # This error block will only ever be hit if the user gives us a funny
    # sequence or incorrect advanced parameter. Well, we could hit this block
    # if someone is playing around with our HTTP API too.
    # error LoadGeoData::ArgumentError, GeoAnalysis::ArgumentError do
    #   status 400
    #   slim :"500", layout: false
    # end

    # This will catch any unhandled error and some very special errors. Ideally
    # we will never hit this block. If we do, there's a bug in GeneValidatorApp
    # or something really weird going on.
    # TODO: If we hit this error block we show the stacktrace to the user
    # requesting them to post the same to our Google Group.
    # error Exception, LoadGeoData::RuntimeError, GeoAnalysis::RuntimeError do
    error Exception do
      status 500
      slim :"500", layout: false
    end

    not_found do
      status 404
      slim :"404", layout: :app_layout
    end
  end
end
