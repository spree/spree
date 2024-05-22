module Spree
  class CustomUserGenerator < Rails::Generators::NamedBase
    include Rails::Generators::ResourceHelpers
    include Rails::Generators::Migration

    desc 'Set up a Spree installation with a custom User class'

    def self.source_paths
      paths = superclass.source_paths
      paths << File.expand_path('templates', __dir__)
      paths.flatten
    end

    def check_for_constant
      klass
    rescue NameError
      @shell.say "Couldn't find #{class_name}. Are you sure that this class exists within your application and is loaded?", :red
      exit(1)
    end

    def generate
      migration_template 'migration.rb.tt', 'db/migrate/add_spree_fields_to_custom_user_table.rb'
      template 'current_user_helpers.rb.tt', 'lib/spree/current_user_helpers.rb'

      file_action = File.exist?('config/initializers/spree.rb') ? :append_file : :create_file
      send(file_action, 'config/initializers/spree.rb') do
        %Q{
          Rails.application.config.to_prepare do
            require_dependency 'spree/current_user_helpers'
          end\n}
      end
    end

    def self.next_migration_number(dirname)
      format('%.3d', (current_migration_number(dirname) + 1))
    end

    def klass
      class_name.constantize
    end

    def table_name
      klass.table_name
    end
  end
end
