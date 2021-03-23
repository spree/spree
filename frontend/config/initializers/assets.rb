Rails.application.config.assets.precompile << 'spree_frontend_manifest.js'
Rails.application.config.assets.configure do |env|
  env.export_concurrent = false
end
