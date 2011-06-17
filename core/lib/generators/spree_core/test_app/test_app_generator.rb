module SpreeCore
  module Generators
    class TestAppGenerator < SpreeCore::Generators::SandboxGenerator
      desc "Internal generator for test applications."

      class_option :app_name, :type => :string,
                              :desc => "The name of the test rails app to generate. Defaults to test_app.",
                              :default => "test_app"

      class << self
        attr_accessor :verbose
      end

      def self.source_paths
        paths = self.superclass.source_paths
        paths << [File.expand_path('../templates/', __FILE__)]
        paths.flatten
      end

      def generate_app
        silence_stream(STDOUT) {
          super
        }
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
          super
        }
      end

      def tweak_gemfile
        silence_stream(STDOUT) {
          super
        }
      end

      def append_db_adapter_gem
        silence_stream(STDOUT) {
          super
        }
      end

      def bundle_install
        silence_stream(STDOUT) {
          super
        }
      end

      def include_seed_data
      end

      def setup_assets
        silence_stream(STDOUT) {
          super
        }
      end

      def configure_application
        silence_stream(STDOUT) {
          super
        }
      end

      def create_databases_yml
        silence_stream(STDOUT) {
          super
        }
      end

      def setup_environments
        silence_stream(STDOUT) {
          template "config/environments/cucumber.rb"
        }
      end

      def copy_migrations
        silence_stream(STDOUT) {
          super
        }
      end

      def run_migrations
        silence_stream(STDOUT) {
          inside application_path do
            run 'bundle exec rake db:drop db:create db:migrate db:seed RAILS_ENV=test'
            run 'bundle exec rake db:drop db:create db:migrate db:seed RAILS_ENV=cucumber'
          end
        }
      end

      private

      def application_path
        "spec/#{test_app}"
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
