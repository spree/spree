= <%= extension_name %>

Each extension loaded by Spree will override the views and stylesheets of those that precede so you will need to configure their load order. Put something like the following in the file config/preinitializer.rb:

    SPREE_EXTENSIONS_LOAD_ORDER = [:localization, :all, :<%= class_name.underscore.gsub("_extension", "") %>, :site]
