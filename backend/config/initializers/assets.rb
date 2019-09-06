Rails.application.config.assets.precompile += %w(admin/* credit_cards/credit_card.gif)
Rails.application.config.assets.paths << Rails.root.join('app', 'assets', 'fonts')
Rails.application.config.assets.precompile << /\.(?:svg|eot|woff|ttf)$/
