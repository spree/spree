module Spree
  class CustomAuthenticationGenerator < Rails::Generators::Base
    desc 'Set up a Spree installation with a custom authentication helpers'

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
    end
  end
end
