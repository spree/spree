module Spree
  module V2
    module Storefront
      class GiftCardSerializer < BaseSerializer
        set_type   :gift_card

        attributes :code, :amount, :amount_remaining, :display_amount, :display_amount_remaining
      end
    end
  end
end
