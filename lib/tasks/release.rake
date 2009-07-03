require 'rubygems'
require 'rake/testtask'
require 'rake/rdoctask'
require 'rake/gempackagetask'
require 'spree'

PKG_NAME = 'spree'
PKG_VERSION = Spree::Version.to_s
PKG_FILE_NAME = "#{PKG_NAME}-#{PKG_VERSION}"
RUBY_FORGE_PROJECT = PKG_NAME
RUBY_FORGE_USER = ENV['RUBY_FORGE_USER'] || 'schof'

RELEASE_NAME  = PKG_VERSION
RUBY_FORGE_GROUPID = '5614'
RUBY_FORGE_PACKAGEID = '7123'

RDOC_TITLE = "Spree -- Complete Commerce Solution for Ruby on Rails"
RDOC_EXTRAS = ["README.markdown", "CONTRIBUTORS", "CHANGELOG", "INSTALL", "LICENSE"]

namespace 'spree' do
  spec = Gem::Specification.new do |s|
    s.name = PKG_NAME
    s.version = PKG_VERSION
    s.summary = 'A complete commerce solution for Ruby on Rails.'
    s.description = "Spree is a complete commerce solution designed for use by experienced Rails developers. No solution can possibly solve everyone’s needs perfectly. There are simply too many ways that people do business for us to model them all specifically. Rather then come up short (like so many projects before it), Spree’s approach is to simply accept this and not even try. Instead Spree tries to focus on solving the 90% of the problem that most commerce projects face and anticipate that the other 10% will need to be addressed by the end developer familiar with the client’s exact business requirements."
    s.author = "Sean Schofield"
    s.email = "sean.schofield@gmail.com"
    s.homepage = 'http://spreecommerce.com/'
    s.rubyforge_project = RUBY_FORGE_PROJECT
    s.platform = Gem::Platform::RUBY
    s.bindir = 'bin'
    s.executables = ['spree']
    s.add_dependency 'rake', '>= 0.7.1'
    s.add_dependency 'highline', '>= 1.4.0'
    s.add_dependency 'rails', '= 2.3.2'
    s.add_dependency 'activemerchant', '>= 1.4.1'
    s.add_dependency 'activerecord-tableless', '>= 0.1.0' 
    s.add_dependency 'calendar_date_select', '= 1.15' 
    s.add_dependency 'tlsmail', '= 0.0.1' 
    s.add_dependency 'rspec', '>= 1.2.0'
    s.add_dependency 'rspec-rails', '>= 1.2.0' 
    # For some reason the authlogic dependency really screws things up (See Issue #433)
    #s.add_dependency 'authlogic', '>= 2.0.11'
    s.has_rdoc = true
    #s.rdoc_options << '--title' << RDOC_TITLE << '--line-numbers' << '--main' << 'README'
    rdoc_excludes = Dir["**"].reject { |f| !File.directory? f }
    rdoc_excludes.each do |e|
      s.rdoc_options << '--exclude' << e
    end
    #s.extra_rdoc_files = RDOC_EXTRAS
    files = FileList['**/*']
    files.exclude '**/._*'
    files.exclude '**/*.rej'
    files.exclude 'cache/'
    #files.exclude 'config/database.yml'
    files.exclude 'config/locomotive.yml'
    files.exclude 'config/lighttpd.conf'
    files.exclude 'config/mongrel_mimes.yml'
    files.exclude 'db/schema.db'
    files.exclude 'db/*.sqlite3'
    files.exclude 'db/*.sql'
    files.exclude /^doc/
    files.exclude 'log/*.log'
    files.exclude 'log/*.pid'
    #files.include 'log/.keep'
    files.exclude /^pkg/
    files.include 'public/.htaccess.example'
    files.exclude 'public/images/products'
    files.exclude 'tmp/'
    s.files = files.to_a
  end

  Rake::GemPackageTask.new(spec) do |pkg|
    pkg.need_zip = true
    pkg.need_tar = true
  end

  namespace :gem do
    desc "Uninstall Gem"
    task :uninstall do
      sh "gem uninstall #{PKG_NAME}" rescue nil
    end

    desc "Install the gems needed for testing"
    task :test_gems do
      system "rake gems:install RAILS_ENV=test"
    end

    desc "Build and install Gem from source"
    task :install => [:test_gems, :package, :uninstall] do
      chdir("#{SPREE_ROOT}/pkg") do
        latest = Dir["#{PKG_NAME}-*.gem"].last
        sh "gem install #{latest}"
      end
    end
  end

  desc "Publish the release files to RubyForge."
  task :release => [:gem, :package] do
    files = ["gem", "tgz"].map { |ext| "pkg/#{PKG_FILE_NAME}.#{ext}" }

    system %{rubyforge login --username #{RUBY_FORGE_USER}}
  
    files.each do |file|
      system %{rubyforge add_release #{RUBY_FORGE_GROUPID} #{RUBY_FORGE_PACKAGEID} "#{RELEASE_NAME}" #{file}}
    end
  end
end
