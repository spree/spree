require 'rails/generators'

module Spree
  module Authentication
    class CustomGenerator < Rails::Generators::Base
      desc 'Set up a Spree installation with custom authentication'

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
      end
    end
  end
end
