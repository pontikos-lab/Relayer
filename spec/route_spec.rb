require 'rack/test'
require 'rspec'
require 'capybara/rspec'
require 'w3c_validators'

require 'oct_segmentation'

# Basic unit tests for HTTP / Rack interface.
module OctSegmentation
  include W3CValidators
  describe 'Routes' do
    ENV['RACK_ENV'] = 'production'
    include Rack::Test::Methods

    let 'root' do
      OctSegmentation.root
    end

    let 'empty_config' do
      File.join(root, 'spec', 'empty_config.yml')
    end

    before :each do
      OctSegmentation.init(config_file: empty_config)

      @params = {

      }
    end

    let 'app' do
      OctSegmentation
    end

    it 'should start the app' do
      get '/analyse'
      last_response.ok?.should == true
    end

    it 'should start the app' do
      get '/analyse'
      last_response.ok?.should == true
    end

    # it 'returns Bad Request (400) if no GEO Database is provided when' \
    #    ' loading Geo Db' do
    #   @params['geo_db'] = ''
    #   post '/load_geo_db', @params
    #   last_response.status.should == 400
    # end

    it 'validate the html' do
      get '/'
      html = last_response.body

      validator = MarkupValidator.new
      results = validator.validate_text(html)

      results.errors.each { |err| puts err.to_s } if results.errors.length > 0
      # Allow Attribute color in element link
      results.errors.length.should == 1
    end
  end
end
