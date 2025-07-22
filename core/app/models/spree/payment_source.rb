# This model is used to store payment sources for non-credit card payments, eg wallet, account, etc.
module Spree
  class PaymentSource < Spree.base_class
    include Spree::Metadata
    include Spree::PaymentSourceConcern

    #
    # Associations
    #
    belongs_to :payment_method, class_name: 'Spree::PaymentMethod'
    belongs_to :user, class_name: Spree.user_class.to_s, optional: true

    #
    # Validations
    #
    validates_uniqueness_of :gateway_payment_profile_id, scope: :type

    #
    # Delegations
    #
    delegate :profile_id, to: :gateway_customer, prefix: true, allow_nil: true

    # Returns the gateway customer for the user.
    # @return [Spree::GatewayCustomer]
    def gateway_customer
      return if user.blank?

      payment_method.gateway_customers.find_by(user: user)
    end
  end
end
