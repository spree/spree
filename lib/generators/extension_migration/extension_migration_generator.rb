require 'rails_generator/base'

class ExtensionMigrationGenerator < Rails::Generator::NamedBase
  
  attr_reader :extension_path, :extension_file_name
  
  def initialize(runtime_args, runtime_options = {})
    super
    @extension_file_name = "#{file_name}_extension"
    @extension_path = "vendor/extensions/#{file_name}"
    @migration_name = runtime_args[1]
  end

  # overload the super method which was causing problems for some unknown reason (too lazy to debug properly)
  def attributes
    []
  end

  def banner
    "Usage: #{$0} extension_migration ExtensionName MigrationName [options]"
  end

  def manifest    
    record do |m|
      m.migration_template 'migration.rb', 
                           "#{extension_path}/db/migrate", 
                           :assigns => {:migration_name => @migration_name},
                           :migration_file_name => @migration_name.underscore
    end
  end

end
