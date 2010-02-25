class ThemeGenerator < Rails::Generator::NamedBase
  attr_reader :theme_path, :theme_file_name

  def initialize(runtime_args, runtime_options = {})
    super
    @theme_file_name = "theme_#{file_name.underscore}_extension"
    @theme_path = "vendor/extensions/theme_#{file_name.underscore}"
  end

  def manifest
    
    record do |m|
      m.directory "#{theme_path}/app/views"
      m.directory "#{theme_path}/lib/tasks"
      m.directory "#{theme_path}/public/stylesheets"
      m.directory "#{theme_path}/public/javascripts"
      m.directory "#{theme_path}/public/images"

      m.template 'README.markdown', "#{theme_path}/README.markdown"
      
      # slight hack so we don't have to keep two copies (themes are extensions after all)
      m.template '../../extension/templates/extension.rb', "#{theme_path}/#{theme_file_name}.rb"
      m.template '../../extension/templates/extension_hooks.rb', "#{theme_path}/#{extension_name.downcase}_hooks.rb"

      #if options[:with_test_unit]
       
       
      #end
      theme_default = '../../../../vendor/extensions/theme_default'

      # eventually we should make this optional plus include admin css etc. 
      m.template "#{theme_default}/public/stylesheets/screen.css", "#{theme_path}/public/stylesheets/screen.css"
    end
  end

  def class_name
    "Theme#{super.to_name.gsub(' ', '')}Extension"
  end

  def extension_name
    class_name.to_name('Extension')
  end

  def add_options!(opt)
    opt.separator ''
    opt.separator 'Generates a new theme with compiled CSS by default'
    opt.separator ''
    
    # TODO - eventually implement these (tricky b/c manifest wants explicit list of files, not just directories)
    
    # opt.separator 'Options:'
    # opt.on("--views", "Copy the views from default theme") { |v| options[:views] = v }
    # opt.on("--everything", "Complete copy of the default theme") { |v| options[:everything] = v }
    # opt.on("--less", "Copy everything from the default theme") { |v| options[:views] = v }    
  end
end
