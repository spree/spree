require 'rails_generator/base'
require 'rails_generator/generators/components/controller/controller_generator'

class ExtensionControllerGenerator < ControllerGenerator

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
      m.class_collisions class_path, "#{class_name}Controller", "#{class_name}Helper"

      # Controller, helper, views, and spec directories.
      m.directory File.join('app/controllers', class_path)
      m.directory File.join('app/helpers', class_path)
      m.directory File.join('app/views', class_path, file_name)
      m.directory File.join('spec/controllers', class_path)
      m.directory File.join('spec/helpers', class_path)
      m.directory File.join('spec/views', class_path, file_name)

      # Controller spec, class, and helper.
      m.template 'controller_spec.rb',
      File.join('spec/controllers', class_path, "#{file_name}_controller_spec.rb")

      m.template 'helper_spec.rb',
      File.join('spec/helpers', class_path, "#{file_name}_helper_spec.rb")

      m.template 'controller:controller.rb',
      File.join('app/controllers', class_path, "#{file_name}_controller.rb")

      m.template 'controller:helper.rb',
      File.join('app/helpers', class_path, "#{file_name}_helper.rb")

      # Spec and view template for each action.
      actions.each do |action|
        m.template 'view_spec.rb',
        File.join('spec/views', class_path, file_name, "#{action}_view_spec.rb"),
        :assigns => { :action => action, :model => file_name }
        path = File.join('app/views', class_path, file_name, "#{action}.html.erb")
        m.template 'controller:view.html.erb',
        path,
        :assigns => { :action => action, :path => path }
      end
    end
  end

  def banner
    "Usage: #{$0} #{spec.name} ExtensionName #{spec.name.camelize}Name [options]"
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
