class ScaffoldResourceGenerator < Rails::Generator::NamedBase
  attr_reader   :controller_name,
                :controller_class_path,
                :controller_file_path,
                :controller_class_nesting,
                :controller_class_nesting_depth,
                :controller_class_name,
                :controller_singular_name,
                :controller_plural_name,
                :resource_edit_path,
                :default_file_extension,
                :generator_default_file_extension
  alias_method  :controller_file_name,  :controller_singular_name
  alias_method  :controller_table_name, :controller_plural_name

  def initialize(runtime_args, runtime_options = {})
    super

    if @rspec = has_rspec?
      if ActionController::Base.respond_to?(:resource_action_separator)
        @resource_edit_path = "/edit"
      else
        @resource_edit_path = ";edit"
      end
    end

    @generator_default_file_extension = (defined? Haml )? "haml" : "erb"
    
    # we want to call erb templates .rhtml or .haml if this is rails 1
    if RAILS_GEM_VERSION.to_i == 1
      @default_file_extension = @generator_default_file_extension == 'erb' ? 'rhtml' : @generator_default_file_extension
    else
      @default_file_extension = "html.#{@generator_default_file_extension}"
    end
    
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

      if @rspec
        m.directory(File.join('spec/controllers', controller_class_path))
        m.directory(File.join('spec/helpers', class_path))
        m.directory(File.join('spec/models', class_path))
        m.directory File.join('spec/views', controller_class_path, controller_file_name)
        m.directory(File.join('spec/fixtures', class_path))
      else
        m.directory(File.join('test/functional', controller_class_path))
        m.directory(File.join('test/unit', class_path))
      end
      
      scaffold_views.each do |action|
        m.template(
          "view_#{action}.#{generator_default_file_extension}",
          File.join('app/views', controller_class_path, controller_file_name, "#{action}.#{default_file_extension}")
        )
      end

      m.template('model.rb', File.join('app/models', class_path, "#{file_name}.rb"))
      m.template('controller.rb', File.join('app/controllers', controller_class_path, "#{controller_file_name}_controller.rb"))
      m.template('helper.rb',          File.join('app/helpers',     controller_class_path, "#{controller_file_name}_helper.rb"))

      if @rspec
        m.template('rspec/functional_spec.rb',  File.join('spec/controllers', controller_class_path, "#{controller_file_name}_controller_spec.rb"))
        m.template('rspec/routing_spec.rb',     File.join('spec/controllers', controller_class_path, "#{controller_file_name}_routing_spec.rb"))
        m.template('rspec/helper_spec.rb',      File.join('spec/helpers',     class_path, "#{controller_file_name}_helper_spec.rb"))
        m.template('rspec/unit_spec.rb',        File.join('spec/models',      class_path, "#{file_name}_spec.rb"))
        m.template('fixtures.yml',        File.join('spec/fixtures',    "#{table_name}.yml"))

        rspec_views.each do |action|
          m.template(
            "rspec/views/#{action}_spec.rb",
            File.join('spec/views', controller_class_path, controller_file_name, "#{action}_spec.rb")
          )
        end

      else
        functional_test = (defined? ThoughtBot::Shoulda) ? "shoulda_functional_test.rb" : "functional_test.rb"

        m.template("#{functional_test}", File.join('test/functional', controller_class_path, "#{controller_file_name}_controller_test.rb"))
        m.template('unit_test.rb',       File.join('test/unit',       class_path, "#{file_name}_test.rb"))
        m.template('fixtures.yml',       File.join('test/fixtures',   "#{table_name}.yml"))
      end


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

  # Lifted from Rick Olson's restful_authentication
  def has_rspec?
    options[:rspec] || (File.exist?('spec') && File.directory?('spec'))
  end
  
  protected
    # Override with your own usage banner.
    def banner
      "Usage: #{$0} scaffold_resource ModelName [field:type, field:type]"
    end

    def rspec_views
      %w[ index show new edit ]
    end
    
    def scaffold_views
      rspec_views + %w[ _form ]
    end

    def model_name 
      class_name.demodulize
    end

    def add_options!(opt)
      opt.separator ''
      opt.separator 'Options:'
      opt.on("--rspec", "Force rspec mode (checks for RAILS_ROOT/spec by default)") { |v| options[:rspec] = true }
    end
end

module Rails
  module Generator
    class GeneratedAttribute
      def default_value
        @default_value ||= case type
          when :int, :integer               then "\"1\""
          when :float                       then "\"1.5\""
          when :decimal                     then "\"9.99\""
          when :datetime, :timestamp, :time then "Time.now"
          when :date                        then "Date.today"
          when :string                      then "\"MyString\""
          when :text                        then "\"MyText\""
          when :boolean                     then "false"
          else
            ""
        end      
      end

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
