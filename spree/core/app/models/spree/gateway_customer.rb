module Spree
  class GatewayCustomer < Spree.base_class
    has_prefix_id :gcus

    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :customer, class_name: Spree.customer_class.to_s
    include Spree::DeprecatedCustomerAlias

    validates :payment_method, presence: true
    validates :customer, presence: true
    validates :profile_id, presence: true
    validates :payment_method_id, uniqueness: { scope: :customer_id }

    # Gateway customers whose payment method is the given provider — gateway
    # gems use this instead of decorating the model with their own scope.
    #
    # @param provider [Class, String] a payment method class, eg. SpreeStripe::Gateway
    scope :for_provider, ->(provider) {
      joins(:payment_method).where(Spree::PaymentMethod.table_name => { type: provider.to_s })
    }

    encrypts :profile_id, deterministic: true if Rails.configuration.active_record.encryption.include?(:primary_key)
  end
end
