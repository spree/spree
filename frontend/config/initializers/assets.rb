Rails.application.config.assets.precompile += %w(favicon.ico credit_cards/* spree/frontend/checkout/shipment)
# fix issues with glyphicons
Rails.application.config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
Rails.application.config.assets.precompile << /\.(?:svg|eot|woff|ttf)$/
