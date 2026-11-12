# This model is used to store payment sources for non-credit card payments, eg wallet, account, etc.
module Spree
  class PaymentSource < Spree.base_class
    has_prefix_id :psrc

    include Spree::HasCustomFields
    include Spree::Metadata
    include Spree::PaymentSourceConcern

    #
    # Associations
    #
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :customer, class_name: Spree.customer_class.to_s, optional: true
    include Spree::DeprecatedCustomerAlias

    #
    # Validations
    #
    # A gateway profile id is only unique within the gateway account that issued it, so the same
    # buyer needs a separate source under each payment method they pay through.
    validates_uniqueness_of :gateway_payment_profile_id, scope: %i[type payment_method_id]

    #
    # Delegations
    #
    delegate :profile_id, to: :gateway_customer, prefix: true, allow_nil: true

    # Returns the gateway customer for the user.
    # @return [Spree::GatewayCustomer]
    def gateway_customer
      return if customer.blank?

      payment_method.gateway_customers.find_by(customer: customer)
    end
  end
end
