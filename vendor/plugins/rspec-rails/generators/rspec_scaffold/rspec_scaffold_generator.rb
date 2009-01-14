require File.dirname(__FILE__) + '/../rspec_default_values'

class RspecScaffoldGenerator < Rails::Generator::NamedBase
  default_options :skip_migration => false
  
  attr_reader   :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_nesting,
                :controller_class_nesting_depth,
                :controller_class_name,
                :controller_singular_name,
                :controller_plural_name,
                :resource_edit_path,
                :default_file_extension
  alias_method  :controller_file_name,  :controller_singular_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    super

    @controller_name = @name.pluralize

    base_name, @controller_class_path, @controller_file_path, @controller_class_nesting, @controller_class_nesting_depth = extract_modules(@controller_name)
    @controller_class_name_without_nesting, @controller_singular_name, @controller_plural_name = inflect_names(base_name)

    if @controller_class_nesting.empty?
      @controller_class_name = @controller_class_name_without_nesting
    else
      @controller_class_name = "#{@controller_class_nesting}::#{@controller_class_name_without_nesting}"
    end
    
    if Rails::VERSION::STRING < "2.0.0"
      @resource_generator = "scaffold_resource"
      @default_file_extension = "rhtml"
		else
      @resource_generator = "scaffold"
      @default_file_extension = "html.erb"
    end
    
    if ActionController::Base.respond_to?(:resource_action_separator)
      @resource_edit_path = "/edit"
    else
      @resource_edit_path = ";edit"
    end
  end

  def manifest
    record do |m|
      
      # Check for class naming collisions.
      m.class_collisions(controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}Helper")
      m.class_collisions(class_path, "#{class_name}")

      # Controller, helper, views, and spec directories.
      m.directory(File.join('app/models', class_path))
      m.directory(File.join('app/controllers', controller_class_path))
      m.directory(File.join('app/helpers', controller_class_path))
      m.directory(File.join('app/views', controller_class_path, controller_file_name))
      m.directory(File.join('spec/controllers', controller_class_path))
      m.directory(File.join('spec/models', class_path))
      m.directory(File.join('spec/helpers', class_path))
      m.directory File.join('spec/fixtures', class_path)
      m.directory File.join('spec/views', controller_class_path, controller_file_name)
      
      # Controller spec, class, and helper.
      m.template 'rspec_scaffold:routing_spec.rb',
        File.join('spec/controllers', controller_class_path, "#{controller_file_name}_routing_spec.rb")

      m.template 'rspec_scaffold:controller_spec.rb',
        File.join('spec/controllers', controller_class_path, "#{controller_file_name}_controller_spec.rb")

      m.template "#{@resource_generator}:controller.rb",
        File.join('app/controllers', controller_class_path, "#{controller_file_name}_controller.rb")

      m.template 'rspec_scaffold:helper_spec.rb',
        File.join('spec/helpers', class_path, "#{controller_file_name}_helper_spec.rb")

      m.template "#{@resource_generator}:helper.rb",
        File.join('app/helpers', controller_class_path, "#{controller_file_name}_helper.rb")

      for action in scaffold_views
        m.template(
          "#{@resource_generator}:view_#{action}.#{@default_file_extension}",
          File.join('app/views', controller_class_path, controller_file_name, "#{action}.#{default_file_extension}")
        )
      end
      
      # Model class, unit test, and fixtures.
      m.template 'model:model.rb',      File.join('app/models', class_path, "#{file_name}.rb")
      m.template 'model:fixtures.yml',  File.join('spec/fixtures', class_path, "#{table_name}.yml")
      m.template 'rspec_model:model_spec.rb',       File.join('spec/models', class_path, "#{file_name}_spec.rb")

      # View specs
      m.template "rspec_scaffold:edit_erb_spec.rb",
        File.join('spec/views', controller_class_path, controller_file_name, "edit.#{default_file_extension}_spec.rb")
      m.template "rspec_scaffold:index_erb_spec.rb",
        File.join('spec/views', controller_class_path, controller_file_name, "index.#{default_file_extension}_spec.rb")
      m.template "rspec_scaffold:new_erb_spec.rb",
        File.join('spec/views', controller_class_path, controller_file_name, "new.#{default_file_extension}_spec.rb")
      m.template "rspec_scaffold:show_erb_spec.rb",
        File.join('spec/views', controller_class_path, controller_file_name, "show.#{default_file_extension}_spec.rb")

      unless options[:skip_migration]
        m.migration_template(
          'model:migration.rb', 'db/migrate', 
          :assigns => {
            :migration_name => "Create#{class_name.pluralize.gsub(/::/, '')}",
            :attributes     => attributes
          }, 
          :migration_file_name => "create_#{file_path.gsub(/\//, '_').pluralize}"
        )
      end

      m.route_resources controller_file_name

    end
  end

  protected
    # Override with your own usage banner.
    def banner
      "Usage: #{$0} rspec_scaffold ModelName [field:type field:type]"
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--skip-migration", 
             "Don't generate a migration file for this model") { |v| options[:skip_migration] = v }
    end

    def scaffold_views
      %w[ index show new edit ]
    end

    def model_name 
      class_name.demodulize
    end
end

module Rails
  module Generator
    class GeneratedAttribute
      def input_type
        @input_type ||= case type
          when :text                        then "textarea"
          else
            "input"
        end      
      end
    end
  end
end
