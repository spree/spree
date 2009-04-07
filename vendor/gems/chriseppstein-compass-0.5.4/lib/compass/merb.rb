# To configure Merb to use compass do the following:
# Merb::BootLoader.after_app_loads do
#   require 'merb-haml'
#   require 'compass'
# end
#
# To use a different sass stylesheets locations as is recommended by compass
# add this configuration to your configuration block:
#
# Merb::Config.use do |c|
#   c[:compass] = {
#     :stylesheets => 'app/stylesheets',
#     :compiled_stylesheets => 'public/stylesheets/compiled'
#   }
# end

Merb::BootLoader.after_app_loads do
  #set up sass if haml load didn't do it -- this happens when using a non-default stylesheet location.
  unless defined?(Sass::Plugin)
    require "sass/plugin" 
    Sass::Plugin.options = Merb::Config[:sass] if Merb::Config[:sass]
  end

  # default the compass configuration if they didn't set it up yet.
  Merb::Config[:compass] ||= {}
  
  # default sass stylesheet location unless configured to something else
  Merb::Config[:compass][:stylesheets] ||= Merb.dir_for(:stylesheet) / "sass"
  
  # default sass css location unless configured to something else
  Merb::Config[:compass][:compiled_stylesheets] ||= Merb.dir_for(:stylesheet)
  
  #define the template hash for the project stylesheets as well as the framework stylesheets.
  template_location = {
    Merb::Config[:compass][:stylesheets] => Merb::Config[:compass][:compiled_stylesheets]
  }
  Compass::Frameworks::ALL.each do |framework|
    template_location[framework.stylesheets_directory] = Merb::Config[:compass][:compiled_stylesheets]
  end
  
  #configure Sass to know about all these sass locations.
  Sass::Plugin.options[:template_location] = template_location
end
