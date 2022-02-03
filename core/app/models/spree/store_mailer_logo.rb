module Spree
  class StoreMailerLogo < Asset
    if Spree.public_storage_service_name
      has_one_attached :attachment, service: Spree.public_storage_service_name
    else
      has_one_attached :attachment
    end

    VALID_CONTENT_TYPES = ['image/png', 'image/jpg', 'image/jpeg'].freeze

    validates :attachment, content_type: VALID_CONTENT_TYPES
  end
end
