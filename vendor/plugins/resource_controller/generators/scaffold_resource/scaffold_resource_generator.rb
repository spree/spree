# HACK - This prevents stupid naming collision error
module Rails
  module Generator
    module Commands
      class Create
        def raise_class_collision(class_name)
          # Do Nothing
        end
      end
    end
  end
end

class ScaffoldResourceGenerator < Rails::Generator::NamedBase
  attr_reader   :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_nesting,
                :controller_class_nesting_depth,
                :controller_class_name,
                :controller_singular_name,
                :controller_plural_name
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
  end

  def manifest
    record do |m|
      # Check for class naming collisions.
      m.class_collisions(controller_class_path, "#{controller_class_name}Controller", "#{controller_class_name}Helper")
      m.class_collisions(class_path, "#{class_name}")

      # Controller, helper, views, and test directories.
      m.directory(File.join('app/models', class_path))
      m.directory(File.join('app/controllers', controller_class_path))
      m.directory(File.join('app/helpers', controller_class_path))
      m.directory(File.join('app/views', controller_class_path, controller_file_name))
      m.directory(File.join('test/functional', controller_class_path))
      m.directory(File.join('test/unit', class_path))
      
      generator_template_ext = (defined? Haml )? "haml" : "erb"
      
      # we want to call erb templates .rhtml or .haml if this is rails 1
      if RAILS_GEM_VERSION.to_i == 1
        template_ext = generator_template_ext == 'erb' ? 'rhtml' : generator_template_ext
      else
        template_ext = "html.#{generator_template_ext}"
      end
      
      scaffold_views.each do |action|
        m.template(
          "view_#{action}.#{generator_template_ext}",
          File.join('app/views', controller_class_path, controller_file_name, "#{action}.#{template_ext}")
        )
      end

      m.template('model.rb', File.join('app/models', class_path, "#{file_name}.rb"))

      m.template(
        'controller.rb', File.join('app/controllers', controller_class_path, "#{controller_file_name}_controller.rb")
      )

      functional_test = (defined? ThoughtBot::Shoulda) ? "shoulda_functional_test.rb" : "functional_test.rb"

      m.template("#{functional_test}", File.join('test/functional', controller_class_path, "#{controller_file_name}_controller_test.rb"))
      m.template('helper.rb',          File.join('app/helpers',     controller_class_path, "#{controller_file_name}_helper.rb"))
      m.template('unit_test.rb',       File.join('test/unit',       class_path, "#{file_name}_test.rb"))
      m.template('fixtures.yml',       File.join('test/fixtures', "#{table_name}.yml"))

      unless options[:skip_migration]
        migration_template = RAILS_GEM_VERSION.to_i == 1 ? 'old_migration.rb' : 'migration.rb'
        
        m.migration_template(
          migration_template, 'db/migrate', 
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
      "Usage: #{$0} scaffold_resource ModelName [field:type, field:type]"
    end

    def scaffold_views
      %w[ index show new edit _form ]
    end

    def model_name 
      class_name.demodulize
    end
end
