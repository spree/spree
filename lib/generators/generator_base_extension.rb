require 'rails_generator'
module Spree
  module GeneratorBaseExtension
    def self.included(base)
      base.class_eval %{
        alias_method_chain :existing_migrations, :extensions
        alias_method_chain :current_migration_number, :extensions
      }
    end

    def existing_migrations_with_extensions(file_name)
      Dir.glob("#{destination_path(@migration_directory)}/[0-9]*_*.rb").grep(/[0-9]+_#{file_name}.rb$/)
    end

    def current_migration_number_with_extensions
      Dir.glob("#{destination_path(@migration_directory)}/[0-9]*.rb").inject(0) do |max, file_path|
        n = File.basename(file_path).split('_', 2).first.to_i
        if n > max then n else max end
      end
    end
  end
end
Rails::Generator::Commands::Base.class_eval { include Spree::GeneratorBaseExtension }