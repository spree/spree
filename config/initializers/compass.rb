require 'compass'
# If you have any compass plugins, require them here.
Compass.configuration do |config|
  config.project_path = RAILS_ROOT
  config.sass_dir = "public/stylesheets/sass"
  config.css_dir = "public/stylesheets/compiled"
end
Compass.configure_sass_plugin!
