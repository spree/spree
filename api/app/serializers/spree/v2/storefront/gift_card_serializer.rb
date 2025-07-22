module Spree
  module V2
    module Storefront
      class GiftCardSerializer < BaseSerializer
        set_type   :gift_card

        attributes :amount, :amount_used, :amount_remaining, :display_amount, :display_amount_used,
                   :display_amount_remaining, :expires_at

        attribute :code, &:display_code
      end
    end
  end
end
