require 'rubygems'
require 'rake'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'rake/contrib/rubyforgepublisher'
require File.join(File.dirname(__FILE__), 'lib', 'support', 'gateway_support')


PKG_VERSION = "1.4.2"
PKG_NAME = "activemerchant"
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"

PKG_FILES = FileList[
    "lib/**/*", "test/**/*", "script/**/*", "[a-zA-Z]*"
].exclude(/\.svn$/)


desc "Default Task"
task :default => 'test:units'

# Run the unit tests
namespace :test do

  Rake::TestTask.new(:units) do |t|
    t.pattern = 'test/unit/**/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.libs << 'test'
    t.verbose = true
  end

  Rake::TestTask.new(:remote) do |t|
    t.pattern = 'test/remote/**/*_test.rb'
    t.ruby_opts << '-rubygems'
    t.libs << 'test'
    t.verbose = true
  end

end

# Genereate the RDoc documentation
Rake::RDocTask.new do |rdoc|
  rdoc.rdoc_dir = 'doc'
  rdoc.title    = "ActiveMerchant library"
  rdoc.options << '--line-numbers' << '--inline-source' << '--main=README'
  rdoc.rdoc_files.include('README', 'CHANGELOG')
  rdoc.rdoc_files.include('lib/**/*.rb')
  rdoc.rdoc_files.exclude('lib/tasks')
end

task :install => [:package] do
  `gem install pkg/#{PKG_FILE_NAME}.gem`
end

task :lines do
  lines = 0
  codelines = 0
  Dir.foreach("lib") { |file_name| 
    next unless file_name =~ /.*rb/

    f = File.open("lib/" + file_name)

    while line = f.gets
      lines += 1
      next if line =~ /^\s*$/
      next if line =~ /^\s*#/
      codelines += 1
    end
  }
  puts "Lines #{lines}, LOC #{codelines}"
end

desc "Delete tar.gz / zip / rdoc"
task :cleanup => [ :clobber_package, :clobber_rdoc ]

spec = Gem::Specification.new do |s|
  s.name = PKG_NAME
  s.version = PKG_VERSION
  s.summary = "Framework and tools for dealing with credit card transactions."
  s.has_rdoc = true

  s.files = PKG_FILES

  s.rubyforge_project = "activemerchant"
  s.require_path = 'lib'
  s.author = "Tobias Luetke"
  s.email = "tobi@leetsoft.com"
  s.homepage = "http://activemerchant.org/"
  
  s.add_dependency('activesupport', '>= 2.3.2')
  s.add_dependency('builder', '>= 2.0.0')
  
  s.signing_key = ENV['GEM_PRIVATE_KEY']
  s.cert_chain  = ['gem-public_cert.pem']
end

Rake::GemPackageTask.new(spec) do |p|
  p.gem_spec = spec
  p.need_tar = true
  p.need_zip = true
end

desc "Release the gems and docs to RubyForge"
task :release => [ :publish, :upload_rdoc ]

desc "Publish the release files to RubyForge."
task :publish => [ :package ] do
  require 'rubyforge'
  
  packages = %w( gem tgz zip ).collect{ |ext| "pkg/#{PKG_NAME}-#{PKG_VERSION}.#{ext}" }
  
  rubyforge = RubyForge.new
  rubyforge.configure
  rubyforge.login
  rubyforge.add_release(PKG_NAME, PKG_NAME, "REL #{PKG_VERSION}", *packages)
end

desc 'Upload RDoc to RubyForge'
task :upload_rdoc => :rdoc do
  user = ENV['RUBYFORGE_USER'] 
  project = "/var/www/gforge-projects/#{PKG_NAME}"
  local_dir = 'doc'
  pub = Rake::SshDirPublisher.new user, project, local_dir
  pub.upload
end

namespace :gateways do
  desc 'Print the currently supported gateways'
  task :print do
    support = GatewaySupport.new
    support.to_s
  end
  
  namespace :print do
    desc 'Print the currently supported gateways in RDoc format'
    task :rdoc do
      support = GatewaySupport.new
      support.to_rdoc
    end
  
    desc 'Print the currently supported gateways in Textile format'
    task :textile do
      support = GatewaySupport.new
      support.to_textile
    end
    
    desc 'Print the gateway functionality supported by each gateway'
    task :features do
      support = GatewaySupport.new
      support.features
    end
  end
end
