module Spree
  module UserPaymentSource
    extend ActiveSupport::Concern

    included do
      has_many :credit_cards, class_name: 'Spree::CreditCard', foreign_key: :user_id, dependent: :destroy
      has_many :payment_setup_sessions, class_name: 'Spree::PaymentSetupSession', foreign_key: :customer_id, dependent: :destroy

      def default_credit_card
        credit_cards.default.first
      end

      def payment_sources
        credit_cards.capturable.not_expired.where(payment_method: Spree::PaymentMethod.active).not_removed
      end

      def drop_payment_source(source)
        gateway = source.payment_method
        gateway.disable_customer_profile(source)
      end
    end
  end
end
