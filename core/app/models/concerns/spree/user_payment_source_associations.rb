module Spree
  module UserPaymentSourceAssociations
    extend ActiveSupport::Concern

    included do
      has_many :user_payment_sources, foreign_key: "user_id"
      has_many :credit_cards,
               through: :user_payment_sources,
               source: :payment_source,
               source_type: 'Spree::CreditCard'

      def default_credit_card; credit_cards.default.first; end

      def payment_sources
        credit_cards.with_payment_profile
      end

      def drop_payment_source(source)
        gateway = source.payment_method
        gateway.disable_customer_profile(source)
      end
    end
  end
end
