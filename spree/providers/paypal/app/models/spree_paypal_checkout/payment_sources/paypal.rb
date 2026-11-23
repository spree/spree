module SpreePaypalCheckout
  module PaymentSources
    # What the buyer paid with in PayPal's window: a PayPal or Venmo account, or
    # a card typed in by a buyer without one. A card is kept here rather than as
    # a Spree::CreditCard: PayPal issues no reusable card id without vaulting,
    # so it could never be charged again and must not appear among saved cards.
    class Paypal < ::Spree::PaymentSource
      WALLETS = %w[paypal venmo].freeze

      store_accessor :metadata, :wallet, :email, :name, :account_id, :account_status, :brand, :last_digits

      # @param payment_source [Hash, nil] the PayPal order's `payment_source`
      # @param payment_method [SpreePaypalCheckout::Gateway]
      # @param customer [Spree::Customer, nil]
      # @param paypal_order_id [String] keys the source
      # @return [Paypal, nil] nil for a kind the gem does not model
      def self.for_payment_source(payment_source, payment_method:, customer:, paypal_order_id:)
        kind, details = Hash(payment_source).find { |key, value| (WALLETS + ['card']).include?(key) && value.is_a?(Hash) }
        return if kind.nil?

        metadata = if kind == 'card'
                     { 'name' => details['name'], 'brand' => details['brand'], 'last_digits' => details['last_digits'] }
                   else
                     {
                       'email' => details['email_address'],
                       'name' => paypal_name(details['name']),
                       'account_id' => details['account_id'],
                       'account_status' => details['account_status'],
                       'user_name' => details['user_name']
                     }
                   end

        # One source per PayPal order: nothing is saved at PayPal to reuse,
        # and a source shared by account would show one customer's payment
        # under another who paid with the same PayPal account.
        source = find_or_initialize_by(payment_method: payment_method, gateway_payment_profile_id: "#{kind}-#{paypal_order_id}")
        source.customer ||= customer
        source.metadata = { 'wallet' => kind }.merge(metadata.compact)
        source.save!
        source
      end

      def self.paypal_name(name)
        return name if name.is_a?(String)
        return if name.blank?

        [name['given_name'], name['surname']].compact.join(' ').presence || name['full_name']
      end

      def self.display_name
        'PayPal'
      end
    end
  end
end
