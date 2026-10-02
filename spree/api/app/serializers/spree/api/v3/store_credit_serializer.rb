module Spree
  module Api
    module V3
      class StoreCreditSerializer < BaseSerializer
        typelize amount: :string, amount_used: :string, amount_remaining: :string,
                 display_amount: :string, display_amount_used: :string, display_amount_remaining: :string,
                 currency: :string

        string_attributes :amount, :amount_used, :amount_remaining, :display_amount, :display_amount_used,
                          :display_amount_remaining

        attributes :currency
      end
    end
  end
end
