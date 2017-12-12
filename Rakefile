require 'bundler/gem_tasks'

task default: [:build]

desc 'Builds and installs'
task install: [:build] do
  require_relative 'lib/relayer/version'
  sh "gem install ./relayer-#{Relayer::VERSION}.gem"
end

desc 'Runs tests and builds gem (default)'
task :build do
  sh 'gem build relayer.gemspec'
end

task test: :spec do
  require 'rspec/core'
  require 'rspec/core/rake_task'
  RSpec::Core::RakeTask.new(:spec) do |spec|
    spec.pattern = FileList['spec/**/*_spec.rb']
  end
end

task :assets do
  require_relative 'lib/relayer/version'
  `rm ./public/assets/css/style-*.min.css`
  `rm ./public/assets/css/style-*.min.css.map`
  sh 'sass -t compressed ./public/assets/css/scss/style.scss' \
  " ./public/assets/css/style-#{Relayer::VERSION}.min.css"
  `rm ./public/assets/js/app-*.min.js`
  `rm ./public/assets/js/app-*.min.js.map`
  sh "uglifyjs './public/assets/js/dependencies/jquery.fine-uploader.min.js'" \
     " './public/assets/js/dependencies/jquery.file-download.js'" \
     " './public/assets/js/dependencies/nouislider.js'" \
     " './public/assets/js/dependencies/underscore.js'" \
     " './public/assets/js/dependencies/relayer.js' -m -c --source-map" \
     " -o './public/assets/js/app-#{Relayer::VERSION}.min.js'"
end

task :criticalcss do
  require_relative 'lib/relayer'
  puts 'Note that Relayer needs to be running on Port 3000 for this to work'
  puts 'You will need to manually insert the Critical CSS'
  puts 'You run `npm install` before running this rake command'
  `rm ./public/assets/css/criticl/home.min.css`
  `rm ./public/assets/css/criticl/app.min.css`
  sh "node #{File.join(Relayer.root, 'public/assets/css/critical/critical.js')}"
end
