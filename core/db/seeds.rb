# Loads seed data out of default dir
Rake::Task["db:load_dir"].invoke( "default" )
puts "Default data has been loaded"