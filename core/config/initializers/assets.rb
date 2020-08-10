Rails.application.config.assets.precompile += %w(logo/spree_50.png noimage/*.png)
Rails.application.config.active_storage.content_types_to_serve_as_binary.delete('image/svg+xml')
