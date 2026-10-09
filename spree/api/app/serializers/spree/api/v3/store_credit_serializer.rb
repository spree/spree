module Spree
  module Api
    module V3
      class StoreCreditSerializer < BaseSerializer
        typelize currency: :string

        money_attributes :amount, :amount_used, :amount_remaining, :display_amount,
                         :display_amount_used, :display_amount_remaining
        attributes :currency
      end
    end
  end
end
