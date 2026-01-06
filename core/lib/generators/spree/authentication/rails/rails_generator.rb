require 'rails/generators'

module Spree
  module Authentication
    class RailsGenerator < Rails::Generators::Base
      desc 'Set up a Spree installation with Rails 8 built-in authentication'

      def self.source_paths
        paths = superclass.source_paths
        paths << File.expand_path('templates', __dir__)
        paths.flatten
      end

      def check_rails_version
        unless Rails::VERSION::MAJOR >= 8
          say 'Rails 8+ is required for built-in authentication. Please use Devise instead:', :red
          say '  rails generate spree:authentication:devise'
          exit 1
        end
      end

      def create_authentication_helpers
        template 'authentication_helpers.rb.tt', 'lib/spree/authentication_helpers.rb'
      end

      def configure_initializer
        file_action = File.exist?('config/initializers/spree.rb') ? :append_file : :create_file
        send(file_action, 'config/initializers/spree.rb') do
          <<~RUBY

            Rails.application.config.to_prepare do
              require_dependency 'spree/authentication_helpers'
            end
          RUBY
        end
      end

      def inject_user_modules
        user_class_file = Rails.root.join('app', 'models', "#{Spree.user_class.name.underscore}.rb")

        if File.exist?(user_class_file)
          inject_into_file user_class_file, after: /class #{Spree.user_class.name} < .*\n/ do
            <<-RUBY
  # Spree modules
  include Spree::UserAddress
  include Spree::UserMethods
  include Spree::UserPaymentSource
            RUBY
          end

          say "Successfully added Spree user modules into #{user_class_file}"
        else
          say "Could not locate user model file at #{user_class_file}. Please add these lines manually:", :red
          say <<~RUBY
            # Spree modules
            include Spree::UserAddress
            include Spree::UserMethods
            include Spree::UserPaymentSource
          RUBY
        end

        inject_admin_user_modules if separate_admin_user?
      end

      def display_post_install_message
        say ''
        say '=' * 60
        say 'Rails Authentication Setup Complete!', :green
        say '=' * 60
        say ''
        say 'Next steps:'
        say '1. Run the admin authentication generator:'
        say '   rails generate spree:admin:rails'
        say '2. Run the storefront authentication generator:'
        say '   rails generate spree:storefront:rails'
        say ''
      end

      private

      def separate_admin_user?
        Spree.admin_user_class != Spree.user_class
      end

      def inject_admin_user_modules
        admin_user_class_file = Rails.root.join('app', 'models', "#{Spree.admin_user_class.name.underscore}.rb")

        if File.exist?(admin_user_class_file)
          inject_into_file admin_user_class_file, after: /class #{Spree.admin_user_class.name} < .*\n/ do
            <<-RUBY
  # Spree modules
  include Spree::UserMethods
            RUBY
          end

          say "Successfully added Spree admin user modules into #{admin_user_class_file}"
        else
          say "Could not locate admin user model file at #{admin_user_class_file}. Please add these lines manually:", :red
          say <<~RUBY
            # Spree modules
            include Spree::UserMethods
          RUBY
        end
      end
    end
  end
end
