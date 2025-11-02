if Rails.application.config.respond_to?(:assets)
  Rails.application.config.assets.precompile << 'spree_storefront_manifest.js'
end
