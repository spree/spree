Rails.application.config.active_storage.content_types_to_serve_as_binary.delete('image/svg+xml')

# https://guides.rubyonrails.org/configuring.html#config-active-storage-web-image-content-types
Rails.application.config.active_storage.web_image_content_types << 'image/webp'
