require 'rails/generators'

module Spree
  module Generators
    class TestAppGenerator < Rails::Generators::Base

      class_option :app_name, :type => :string,
                              :desc => "The name of the test rails app to generate. Defaults to test_app.",
                              :default => "test_app"

      def self.source_root
        File.expand_path('../../templates', __FILE__)
      end

      def generate_app
        remove_directory_if_exists("spec/#{test_app}")
        inside "spec" do
          run "rails new #{test_app} -GJT --skip-gemfile"
        end
      end

      def create_root
        self.destination_root = File.expand_path("spec/#{test_app}", destination_root)
      end

      def remove_unneeded_files
        remove_file "doc"
        remove_file "lib/tasks"
        remove_file "public/images/rails.png"
        remove_file "public/index.html"
        remove_file "README"
        remove_file "vendor"
      end

      def replace_gemfile
        template "Gemfile"
      end

      def create_cucumber_environment
        template "config/environments/cucumber.rb"
      end

      def create_databases_yml
        remove_file "config/database.yml"
        template "config/database.yml"
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
  end
end
