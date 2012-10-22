module Spree
  module Core
    class Engine < ::Rails::Engine
      isolate_namespace Spree
      engine_name 'spree'

      config.middleware.use "Spree::Core::Middleware::SeoAssist"
      config.middleware.use "Spree::Core::Middleware::RedirectLegacyProductUrl"

      config.autoload_paths += %W(#{config.root}/lib)

      # We need to reload the routes here due to how Spree sets them up.
      # The different facets of Spree (auth, promo, etc.) append/prepend routes to Core
      # *after* Core has been loaded.
      #
      # So we wait until after initialization is complete to do one final reload.
      # This then makes the appended/prepended routes available to the application.
      config.after_initialize do
        Rails.application.routes_reloader.reload!
      end

      # filter sensitive information during logging
      initializer "spree.params.filter" do |app|
        app.config.filter_parameters += [:password, :password_confirmation, :number]
      end

      # sets the manifests / assets to be precompiled, even when initialize_on_precompile is false
      initializer "spree.assets.precompile", :group => :all do |app|
        app.config.assets.precompile += %w[
          store/all.*
          admin/all.*
          admin/orders/edit_form.js
          admin/address_states.js
          jqPlot/excanvas.min.js
          admin/images/new.js
          jquery.jstree/themes/apple/*
        ]
      end

    end
  end
end
