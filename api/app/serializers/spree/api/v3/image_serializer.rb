module Spree
  module Api
    module V3
      class ImageSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            position: resource.position,
            alt: resource.alt,
            original_url: image_url(resource),
            large_url: image_url(resource, size: [1200, 1200]),
            medium_url: image_url(resource, size: [600, 600]),
            small_url: image_url(resource, size: [300, 300]),
            thumbnail_url: image_url(resource, size: [150, 150])
          }
        end
      end
    end
  end
end
