module Spree
  module V2
    module Storefront
      class PromotionSerializer < BaseSerializer
        set_type   :promotion

        attributes :name, :description, :amount, :display_amount
      end
    end
  end
end
