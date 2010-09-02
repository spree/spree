require 'thor/group'

class TestAppGenerator < Thor::Group
  include Thor::Actions
  
  class_option :app_name, :type => :string,
                          :desc => "The name of the test rails app to generate. Defaults to test_app.",
                          :default => "test_app"
  
  def self.source_root
    File.expand_path('../templates', __FILE__)
  end
  
  def generate_app
    remove_directory_if_exists("spec/#{test_app}")
    inside "spec" do
      run "rails new #{test_app} -JT"
    end
  end
  
  def create_root
    self.destination_root = File.expand_path("spec/#{test_app}", destination_root)
  end
  
  def remove_unneeded_files
    remove_file ".gitignore"
    remove_file "doc"
    remove_file "Gemfile"
    remove_file "lib/tasks"
    remove_file "public/images/rails.png"
    remove_file "public/index.html"
    remove_file "README"
    remove_file "vendor"
  end
  
  def hijack_bundler
    inside "config" do
      remove_file "boot.rb"
      create_file "boot.rb", <<-file
require 'rubygems'
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../../../Gemfile', __FILE__)
puts "Using Gemfile at \#{ENV['BUNDLE_GEMFILE']}"
require 'bundler'
Bundler.setup
file
      gsub_file "application.rb", "Bundler.require(:default, Rails.env)", "Bundler.require(:test_rails_app, Rails.env)"
    end
  end
  
  def create_cucumber_environment
    template "config/environments/cucumber.rb"
  end
  
  def create_databases_yml
    remove_file "config/database.yml"
    template "config/database.yml"
  end
  
  def install_spree
    inside "" do
      run "rails generate spree_core:install --force"
    end
  end
  
  private
  
  def run_migrations
    inside "" do
      run "rake db:migrate db:seed RAILS_ENV=test"
      run "rake db:migrate db:seed RAILS_ENV=cucumber"
    end
  end
  
  def test_app
    options[:app_name]
  end
  
  def remove_directory_if_exists(path)
    run "rm -r #{path}" if File.directory?(path)
  end
end
