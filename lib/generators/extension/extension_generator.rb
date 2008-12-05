class ExtensionGenerator < Rails::Generator::NamedBase
  default_options :with_test_unit => false

  attr_reader :extension_path, :extension_file_name

  def initialize(runtime_args, runtime_options = {})
    super
    @extension_file_name = "#{file_name}_extension"
    @extension_path = "vendor/extensions/#{file_name}"
  end

  def manifest
    record do |m|
      m.directory "#{extension_path}/app/controllers"
      m.directory "#{extension_path}/app/helpers"
      m.directory "#{extension_path}/app/models"
      m.directory "#{extension_path}/app/views"
      m.directory "#{extension_path}/db/migrate"
      m.directory "#{extension_path}/db/sample"
      m.directory "#{extension_path}/lib/tasks"
      m.directory "#{extension_path}/config"
      m.directory "#{extension_path}/public"

      m.template 'README.markdown',              "#{extension_path}/README.markdown"
      m.template 'extension.rb',        "#{extension_path}/#{extension_file_name}.rb"
      m.template 'tasks.rake',          "#{extension_path}/lib/tasks/#{extension_file_name}_tasks.rake"
      m.template 'routes.rb',          "#{extension_path}/config/routes.rb"

      if options[:with_test_unit]
        m.directory "#{extension_path}/test/fixtures"
        m.directory "#{extension_path}/test/functional"
        m.directory "#{extension_path}/test/unit"

        m.template 'Rakefile',            "#{extension_path}/Rakefile"
        m.template 'test_helper.rb',      "#{extension_path}/test/test_helper.rb"
        m.template 'functional_test.rb',  "#{extension_path}/test/functional/#{extension_file_name}_test.rb"
      else
        m.directory "#{extension_path}/spec/controllers"
        m.directory "#{extension_path}/spec/models"
        m.directory "#{extension_path}/spec/views"
        m.directory "#{extension_path}/spec/helpers"

        m.template 'RSpecRakefile',       "#{extension_path}/Rakefile"
        m.template 'spec_helper.rb',      "#{extension_path}/spec/spec_helper.rb"
        m.file     'spec.opts',           "#{extension_path}/spec/spec.opts"
      end
    end
  end

  def class_name
    super.to_name.gsub(' ', '') + 'Extension'
  end

  def extension_name
    class_name.to_name('Extension')
  end

  def add_options!(opt)
    opt.separator ''
    opt.separator 'Options:'
    opt.on("--with-test-unit",
           "Use Test::Unit for this extension instead of RSpec") { |v| options[:with_test_unit] = v }
  end
end
