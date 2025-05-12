module Spree
  module Api
    module V2
      module Platform
        class GiftCardSerializer < BaseSerializer
          set_type :gift_card

          attributes :state, :code, :expires_at,
                     :amount, :amount_remaining, :minimum_order_amount,
                     :display_amount, :display_amount_remaining, :display_minimum_order_amount

          belongs_to :user
        end
      end
    end
  end
end
