module Spree
  class DummyModelGenerator < Rails::Generators::NamedBase
    include Rails::Generators::ResourceHelpers
    include Rails::Generators::Migration

    desc 'Set up Dummy Model which is used for tests'

    def self.source_paths
      paths = superclass.source_paths
      paths << File.expand_path('templates', __dir__)
      paths.flatten
    end

    def generate
      migration_template 'migration.rb.tt', 'db/migrate/create_spree_dummy_models.rb'
      template 'model.rb.tt', 'app/models/spree/dummy_model.rb'
    end

    def self.next_migration_number(dirname)
      format('%.3d', (current_migration_number(dirname) + 1))
    end
  end
end
