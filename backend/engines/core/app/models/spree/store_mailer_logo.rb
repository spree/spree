module Spree
  class StoreMailerLogo < Asset
    VALID_CONTENT_TYPES = ['image/png', 'image/jpg', 'image/jpeg'].freeze

    validates :attachment, content_type: VALID_CONTENT_TYPES
  end
end
