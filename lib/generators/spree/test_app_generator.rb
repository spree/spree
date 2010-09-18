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

      def setup_environments
        template "config/environments/cucumber.rb"
        append_file "config/environments/test.rb" do
<<-constantz
CART = "cart"
ADDRESS = "address"
DELIVERY = "delivery"
PAYMENT = "payment"
CONFIRM = "confirm"
COMPLETE = "complete"
CANCELED = "canceled"
RETURNED = "returned"
RETURN_AUTHORIZED = "awaiting_return"

ORDER_STATES = [CART, ADDRESS, DELIVERY, PAYMENT, CONFIRM, COMPLETE, CANCELED, RETURNED, RETURN_AUTHORIZED]

READY = "ready"
SHIPPED = "shipped"
PARTIAL = "partial"
PENDING = "pending"
BACKORDER = "backorder"

SHIPMENT_STATES = [READY, SHIPPED, PARTIAL, PENDING, BACKORDER]

PROCESSING = 'processing'
FAILED = 'failed'
COMPLETED = 'completed'
VOID = 'void'
CHECKOUT = 'checkout'

PAYMENT_STATES = [CHECKOUT, PROCESSING, FAILED, COMPLETED, VOID, PENDING]
constantz
        end
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
