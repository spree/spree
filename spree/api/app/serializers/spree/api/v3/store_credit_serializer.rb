module Spree
  module Api
    module V3
      class StoreCreditSerializer < BaseSerializer
        typelize amount: :string, amount_used: :string, amount_remaining: :string,
                 display_amount: :string, display_amount_used: :string, display_amount_remaining: :string,
                 currency: :string

        attributes amount: :string, amount_used: :string, amount_remaining: :string, display_amount: :string,
                   display_amount_used: :string, display_amount_remaining: :string
        attributes :currency
      end
    end
  end
end
