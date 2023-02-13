Rails.application.config.assets.precompile << 'spree_emails_manifest.js'
Rails.application.config.assets.paths << Rails.root.join("..", "..", "..", "core", "lib", "generators", "spree", "core", "install", "templates", "vendor", "assets", "javascripts")
Rails.application.config.assets.paths << Rails.root.join("..", "..", "..", "core", "lib", "generators", "spree", "core", "install", "templates", "vendor", "assets", "stylesheets")
