require 'rails/generators'
require 'rails/generators/migration'

module Spree
  module Authentication
    class DummyGenerator < Rails::Generators::Base
      include Rails::Generators::Migration

      desc 'Set up a Spree installation with dummy authentication for testing'

      def self.source_paths
        paths = superclass.source_paths
        paths << File.expand_path('templates', __dir__)
        paths.flatten
      end

      def self.next_migration_number(dirname)
        format('%.3d', (current_migration_number(dirname) + 1))
      end

      def generate
        # Create admin_users table migration for LegacyAdminUser
        migration_template 'create_spree_admin_users.rb.tt', 'db/migrate/create_spree_admin_users.rb'

        # Create authentication helpers
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
end
