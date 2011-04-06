require 'rails/generators'

module Spree
  module Generators
    class TestAppGenerator < Rails::Generators::Base

      class << self
        attr_accessor :verbose
      end

      class_option :app_name, :type => :string,
                              :desc => "The name of the test rails app to generate. Defaults to test_app.",
                              :default => "test_app"

      def self.source_root
        File.expand_path('../../templates', __FILE__)
      end

      def generate_app
          remove_directory_if_exists("spec/#{test_app}")
          inside "spec" do
            run "rails new #{test_app} --database=#{database_name} -GJTq --skip-gemfile"
          end
      end

      def create_rspec_gemfile
        # newer versions of rspec require a Gemfile in the local gem dirs so create one there as well as in spec/test_app
        silence_stream(STDOUT) {
          template "Gemfile", :force => true
          remove_file "Gemfile.lock"
        }
      end

      def create_root
        self.destination_root = File.expand_path("spec/#{test_app}", destination_root)
      end

      def remove_unneeded_files
        silence_stream(STDOUT) {
          remove_file "doc"
          remove_file "lib/tasks"
          remove_file "public/images/rails.png"
          remove_file "public/index.html"
          remove_file "README"
          remove_file "vendor"
        }
      end

      def replace_gemfile
        silence_stream(STDOUT) {
          template "Gemfile"
        }
      end

      def setup_environments
        silence_stream(STDOUT) {
          template "config/environments/cucumber.rb"
        }
      end

      def create_databases_yml
        silence_stream(STDOUT) {
          remove_file "config/database.yml"
          template "config/database.yml.#{database_name}"
          mv "spec/test_app/config/database.yml.#{database_name}", "spec/test_app/config/database.yml", :verbose => false
        }
      end

      def tweak_gemfile
        silence_stream(STDOUT) {
          append_file '../../Gemfile' do
            full_path_for_local_gems
          end

          append_file 'Gemfile' do
            full_path_for_local_gems
          end
        }
      end

      def append_db_adapter_gem
        silence_stream(STDOUT) {
          case database_name
          when "mysql"
            gem "mysql2"
            append_file '../../Gemfile' do
              "gem 'mysql2'"
            end
          else
            gem "sqlite3-ruby"
            append_file '../../Gemfile' do
              "gem 'sqlite3-ruby'"
            end
          end
        }
      end

      protected
      def full_path_for_local_gems
        # Gemfile needs to be full local path to the source (ex. /Users/schof/repos/spree/auth)
        # By default we do nothing but each gem should override this method with the appropriate content
      end

      private

      def run_migrations
        silence_stream(STDOUT) {
          inside "" do
              run "rake db:drop db:create db:migrate db:seed RAILS_ENV=test"
              run "rake db:drop db:create db:migrate db:seed RAILS_ENV=cucumber"
          end
        }
      end

      def test_app
        options[:app_name]
      end

      def database_name
        ENV['DB_NAME'] || "sqlite3"
      end

      def remove_directory_if_exists(path)
        silence_stream(STDOUT) {
          run "rm -r #{path}" if File.directory?(path)
        }
      end

      def silence_stream(stream)
        if self.class.verbose
          yield
        else
          begin
            old_stream = stream.dup
            stream.reopen(RbConfig::CONFIG['host_os'] =~ /mswin|mingw/ ? 'NUL:' : '/dev/null')
            stream.sync = true
            yield
          ensure
            stream.reopen(old_stream)
          end
        end
      end
    end
  end
end