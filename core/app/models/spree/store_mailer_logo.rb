module Spree
  class StoreMailerLogo < Asset
    if Spree.public_storage_service_name
      has_one_attached :attachment, service: Spree.public_storage_service_name
    else
      has_one_attached :attachment
    end

    validates :attachment, content_type: VALID_CONTENT_TYPES

    VALID_CONTENT_TYPES = ['image/png', 'image/jpg', 'image/jpeg'].freeze
  end
end
