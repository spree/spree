module Spree
  module V2
    module Storefront
      class PromotionSerializer < BaseSerializer
        include Spree::Api::V2::PublicMetafieldsConcern

        set_id     :promotion_id
        set_type   :promotion

        attributes :name, :description, :amount, :display_amount, :code, :public_metadata
      end
    end
  end
end
