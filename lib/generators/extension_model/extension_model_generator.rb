require 'rails_generator/base'
require 'rails_generator/generators/components/model/model_generator'

# Current migration number should be based on the migrations specific to the extension (and not the app as a whole)
class Rails::Generator::Commands::Base
  protected
    def migration_directory(relative_path)
      directory(@migration_directory = "#{extension_path}/db/migrate")
    end
end

# Fix issue with the Destroy command not looking in the correct directory
class Rails::Generator::Commands::Destroy
  protected
    def migration_template(relative_source, relative_destination, template_options = {})
      directory(@migration_directory = "#{extension_path}/db/migrate")
      migration_file_name = "#{template_options[:migration_file_name]}"

      existing_migrations(migration_file_name).each do |file_path|
        file_path.gsub!(extension_path, "")
        file(relative_source, file_path)
      end
    end
end

class ExtensionModelGenerator < ModelGenerator
  
  attr_accessor :extension_name
  
  def initialize(runtime_args, runtime_options = {})
    runtime_args = runtime_args.dup
    @extension_name = runtime_args.shift
    super(runtime_args, runtime_options)
  end
  
  def manifest
    if extension_uses_rspec?
      rspec_manifest
    else
      super
    end
  end
  
  def rspec_manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions class_path, class_name

      # Model, spec, and fixture directories.
      m.directory File.join('app/models', class_path)
      m.directory File.join('spec/models', class_path)
      # m.directory File.join('spec/fixtures', class_path)

      # Model class, spec and fixtures.
      m.template 'model:model.rb',      File.join('app/models', class_path, "#{file_name}.rb")
      # m.template 'model:fixtures.yml',  File.join('spec/fixtures', class_path, "#{table_name}.yml")
      m.template 'model_spec.rb',       File.join('spec/models', class_path, "#{file_name}_spec.rb")

      unless options[:skip_migration]
        m.migration_template 'model:migration.rb', 'db/migrate', :assigns => {
          :migration_name => "Create#{class_name.pluralize.gsub(/::/, '')}"
        }, :migration_file_name => "create_#{file_path.gsub(/\//, '_').pluralize}"
      end
    end
  end
  
  def banner
    "Usage: #{$0} extension_model ExtensionName ModelName [field:type, field:type]"
  end
  
  def extension_path
    File.join('vendor', 'extensions', @extension_name.underscore)
  end
  
  def destination_root
    File.join(RAILS_ROOT, extension_path)
  end
  
  def extension_uses_rspec?
    File.exists?(File.join(destination_root, 'spec'))
  end

end