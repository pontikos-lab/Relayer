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
  `rm ./public/assets/css/app-*.min.css`
  sh 'cleancss --s0 -s --skip-rebase -o' \
     " './public/assets/css/app-#{Relayer::VERSION}.min.css'" \
     " './public/assets/css/app.css'"
  sh "uglifyjs './public/assets/js/jquery.fine-uploader.min.js'" \
     " './public/assets/js/app.js' -m -c -o" \
     " './public/assets/js/app-#{Relayer::VERSION}.min.js'"
end
