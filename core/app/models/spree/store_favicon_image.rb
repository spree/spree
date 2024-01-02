module Spree
  class StoreFaviconImage < Asset
    if Spree.public_storage_service_name
      has_one_attached :attachment, service: Spree.public_storage_service_name
    else
      has_one_attached :attachment
    end

    VALID_CONTENT_TYPES = ['image/png', 'image/x-icon', 'image/vnd.microsoft.icon'].freeze

    validates :attachment,
              content_type: VALID_CONTENT_TYPES,
              size: { less_than_or_equal_to: 1.megabyte }

    validates :attachment,
              if: :is_png?,
              dimension: { max: 256..256 },
              aspect_ratio: :square

    private

    def is_png?
      attachment.content_type.in?('image/png')
    end
  end
end
