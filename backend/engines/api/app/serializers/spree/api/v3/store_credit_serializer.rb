module Spree
  module Api
    module V3
      class StoreCreditSerializer < BaseSerializer
        typelize amount: :string, amount_used: :string, amount_remaining: :string,
                 display_amount: :string, display_amount_used: :string, display_amount_remaining: :string,
                 currency: :string

        attribute :amount do |store_credit|
          store_credit.amount.to_s
        end

        attribute :amount_used do |store_credit|
          store_credit.amount_used.to_s
        end

        attribute :amount_remaining do |store_credit|
          store_credit.amount_remaining.to_s
        end

        attribute :display_amount do |store_credit|
          store_credit.display_amount.to_s
        end

        attribute :display_amount_used do |store_credit|
          store_credit.display_amount_used.to_s
        end

        attribute :display_amount_remaining do |store_credit|
          store_credit.display_amount_remaining.to_s
        end

        attributes :currency
      end
    end
  end
end
