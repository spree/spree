require 'rails/generators'

module Spree
  module Authentication
    class DeviseGenerator < Rails::Generators::Base
      desc 'Set up a Spree installation with Devise as authentication'

      def self.source_paths
        paths = superclass.source_paths
        paths << File.expand_path('templates', __dir__)
        paths.flatten
      end

      def generate
        template 'authentication_helpers.rb.tt', 'lib/spree/authentication_helpers.rb'

        file_action = File.exist?('config/initializers/spree.rb') ? :append_file : :create_file
        send(file_action, 'config/initializers/spree.rb') do
          %Q{
            Rails.application.config.to_prepare do
              require_dependency 'spree/authentication_helpers'
            end\n}
        end

        user_class_file = Rails.root.join('app', 'models', "#{Spree.user_class.name.underscore}.rb")

        if File.exist?(user_class_file)
          inject_into_file user_class_file, after: "class #{Spree.user_class.name} < ApplicationRecord\n" do
            <<-RUBY
    # Spree modules
    include Spree::UserAddress
    include Spree::UserMethods
    include Spree::UserPaymentSource
            RUBY
          end
          gsub_file user_class_file, "< ApplicationRecord", "< Spree.base_class"

          say "Successfully added Spree user modules into #{user_class_file}"
        else
          say "Could not locate user model file at #{user_class_file}. Please add these lines manually:", :red
          say <<~RUBY
            # Spree modules
            include Spree::UserAddress
            include Spree::UserMethods
            include Spree::UserPaymentSource
          RUBY

          say "Please replace < ApplicationRecord with < Spree.base_class in #{user_class_file}"
        end

        if Spree.admin_user_class != Spree.user_class
          admin_user_class_file = Rails.root.join('app', 'models', "#{Spree.admin_user_class.name.underscore}.rb")

          if File.exist?(admin_user_class_file)
            inject_into_file admin_user_class_file, after: "class #{Spree.admin_user_class.name} < ApplicationRecord\n" do
              <<-RUBY
    # Spree modules
    include Spree::UserMethods
              RUBY
            end
            gsub_file admin_user_class_file, "< ApplicationRecord", "< Spree.base_class"

            say "Successfully added Spree admin user modules into #{admin_user_class_file}"
          else
            say "Could not locate admin user model file at #{admin_user_class_file}. Please add these lines manually:", :red
            say <<~RUBY
              # Spree modules
              include Spree::UserMethods
            RUBY

            say "Please replace < ApplicationRecord with < Spree.base_class in #{admin_user_class_file}"
          end
        end

        append_file 'config/initializers/spree.rb' do
          %Q{
            if defined?(Devise) && Devise.respond_to?(:parent_controller)
              Devise.parent_controller = "Spree::BaseController"
            end\n}
        end
      end
    end
  end
end
