module Spree
  module V2
    module Storefront
      class ImageSerializer < BaseSerializer
        set_type  :image

        attribute :id

        # TODO: Add image URL. Include support for both ActiveStorage / Paperclip
      end
    end
  end
end
