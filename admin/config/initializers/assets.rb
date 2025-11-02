if Rails.application.config.respond_to?(:assets)
  Rails.application.config.assets.precompile << 'spree_admin_manifest.js'
end
