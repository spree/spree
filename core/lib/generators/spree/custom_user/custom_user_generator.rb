module Spree
  class CustomUserGenerator < Rails::Generators::NamedBase
    include Rails::Generators::ResourceHelpers

    desc "Set up a Spree installation with a custom User class"

    def self.source_paths
      paths = self.superclass.source_paths
      paths << File.expand_path('../templates', __FILE__)
      paths.flatten
    end

    def generate
      template 'migration.rb.tt', "db/migrate/#{Time.now.strftime("%Y%m%d%H%m%S")}_add_spree_fields_to_custom_user_table.rb"
      template 'controller_helpers_ext.rb.tt', "lib/spree/core/controller_helpers_ext.rb"

      insert_into_file 'config/initializers/spree.rb', :before => "# Configure Spree Preferences" do
        %Q{require 'spree/core/controller_helpers_ext'\n}
      end
    end

    def klass
      class_name.constantize
    end

    def table_name
      klass.table_name
    end

  end
end

