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

    encrypts :profile_id, deterministic: true if Rails.configuration.active_record.encryption.include?(:primary_key)
  end
end
