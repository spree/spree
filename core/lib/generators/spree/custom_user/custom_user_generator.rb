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
      template 'authentication_helpers.rb.tt', "lib/spree/authentication_helpers.rb"

      append_file 'config/initializers/spree.rb' do
        %Q{require 'spree/authentication_helpers'\n}
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

