Rails.application.config.assets.precompile << 'spree_core_manifest.js'
Rails.application.config.active_storage.content_types_to_serve_as_binary.delete('image/svg+xml')
Rails.application.config.assets.configure do |env|
  env.export_concurrent = false
end
