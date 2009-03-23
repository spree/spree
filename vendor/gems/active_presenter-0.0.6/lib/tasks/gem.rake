require 'rake/gempackagetask'

task :clean => :clobber_package

spec = Gem::Specification.new do |s|
  s.name                  = ActivePresenter::NAME
  s.version               = ActivePresenter::VERSION::STRING
  s.summary               = 
  s.description           = "ActivePresenter is the presenter library you already know! (...if you know ActiveRecord)"
  s.author                = "James Golick & Daniel Haran"
  s.email                 = 'james@giraffesoft.ca'
  s.homepage              = 'http://jamesgolick.com/active_presenter'
  s.rubyforge_project     = 'active_presenter'
  s.has_rdoc              = true

  s.required_ruby_version = '>= 1.8.5'

  s.files                 = %w(README LICENSE Rakefile) +
                            Dir.glob("{lib,test}/**/*")
  
  s.require_path          = "lib"
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
end

task :tag_warn do
  puts "*" * 40
  puts "Don't forget to tag the release:"
  puts
  puts "  git tag -a v#{ActivePresenter::VERSION::STRING}"
  puts
  puts "or run rake tag"
  puts "*" * 40
end

task :tag do
  sh "git tag -a v#{ActivePresenter::VERSION::STRING}"
end
task :gem => :tag_warn

namespace :gem do  
  namespace :upload do

    desc 'Upload gems (ruby & win32) to rubyforge.org'
    task :rubyforge => :gem do
      sh 'rubyforge login'
      sh "rubyforge add_release giraffesoft active_presenter #{ActivePresenter::VERSION::STRING} pkg/#{spec.full_name}.gem"
      sh "rubyforge add_file    giraffesoft active_presenter #{ActivePresenter::VERSION::STRING} pkg/#{spec.full_name}.gem"
    end
    
  end
end

task :install => [:clobber, :package] do
  sh "sudo gem install pkg/#{spec.full_name}.gem"
end

task :uninstall => :clean do
  sh "sudo gem uninstall -v #{ActivePresenter::VERSION::STRING} -x #{ActivePresenter::NAME}"
end
