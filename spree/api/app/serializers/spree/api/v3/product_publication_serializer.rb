module Spree
  module Api
    module V3
      class ProductPublicationSerializer < PublicationSerializer
        typelize product_id: :string

        prefixed_id_attributes :product
      end
    end
  end
end
