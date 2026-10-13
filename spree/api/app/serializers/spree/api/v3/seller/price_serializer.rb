module Spree
  module Api
    module V3
      module Seller
        class PriceSerializer < V3::PriceSerializer
          without_formatted_money(:seller)
          _attributes.delete(:amount_in_cents)
          _attributes.delete(:compare_at_amount_in_cents)
        end
      end
    end
  end
end
