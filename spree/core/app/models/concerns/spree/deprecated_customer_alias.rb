module Spree
  # Deprecation shim for the 6.0 user_id -> customer_id / belongs_to :user -> :customer
  # rename. Included by customer-facing models so `.user` / `.user_id` keep working
  # for one release. Remove in Spree 6.1.
  module DeprecatedCustomerAlias
    extend ActiveSupport::Concern

    included do
      alias_attribute :user_id, :customer_id
    end

    def user
      Spree::Deprecation.warn("#{self.class}#user is deprecated and will be removed in Spree 6.1. Use #customer instead.") if defined?(Spree::Deprecation)
      customer
    end

    def user=(value)
      Spree::Deprecation.warn("#{self.class}#user= is deprecated and will be removed in Spree 6.1. Use #customer= instead.") if defined?(Spree::Deprecation)
      self.customer = value
    end
  end
end
