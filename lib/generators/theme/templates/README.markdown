= <%= extension_name %>

Each extension loaded by Spree will override the views and stylesheets of those that precede so you will need to configure their load order. Put something like the following inside the initializer block in the file config/environment.rb:

    config.extensions = [:all, :<%= class_name.underscore.gsub("_extension", "") %>, :site]
