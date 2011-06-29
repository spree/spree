module SpreeCore
  module Generators
    class SandboxGenerator < SpreeCore::Generators::SiteGenerator
      desc "Creates blank Rails application, installs Spree and all sample data"

      def self.source_paths
        paths = self.superclass.source_paths
        paths << [File.expand_path('../../shared/templates/', __FILE__),File.expand_path('../templates', __FILE__)]
        paths.flatten
      end

      def bundler_check
        if defined? Bundler
          #probably being called via bundle exec, can't call bunlde install this way
          
          puts %Q{
          ERROR: Bundler is already loaded.

          If you are running this command via `bundle exec` please re-run the command directly.
          }
          exit
        end
      end

      def generate_app
        remove_directory_if_exists(application_path)
        run "rails new #{application_path} --database=#{database_name} -GJTq --skip-gemfile"
      end 

      def set_destination
        self.destination_root = File.expand_path(application_path, destination_root)
      end

      def replace_gemfile
        template "Gemfile"
      end

      def tweak_gemfile
        additions_for_gemfile.each do |name, path|
          gem name.to_s, :path => path
        end
      end

      def append_db_adapter_gem
        case database_name
          when "mysql"
            gem "mysql2", "0.2.7"
          else
            gem "sqlite3-ruby"
          end
      end

      def create_databases_yml
        remove_file "config/database.yml"
        template "config/database.yml.#{database_name}", "config/database.yml"
      end

      def run_migrations
        inside application_path do
          run 'rake db:bootstrap AUTO_ACCEPT=true'
        end
      end

      private
      def application_path
        "sandbox"
      end

      def database_name
        "sqlite3"
      end

      def additions_for_gemfile
        { :spree => File.expand_path("./") }
      end
    end
  end
end
