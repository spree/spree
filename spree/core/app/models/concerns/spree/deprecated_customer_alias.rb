module Spree
  # Deprecation shim for the 6.0 user_id -> customer_id / belongs_to :user -> :customer
  # rename. Included by customer-facing models so `.user` / `.user_id` keep working
  # until Spree 6.5.
  module DeprecatedCustomerAlias
    extend ActiveSupport::Concern

    included do
      alias_attribute :user_id, :customer_id
    end

    def user
      if defined?(Spree::Deprecation)
        Spree::Deprecation.warn(
          "#{self.class}#user is deprecated and will be removed in Spree 6.5. Use #customer instead."
        )
      end
      customer
    end

    def user=(value)
      if defined?(Spree::Deprecation)
        Spree::Deprecation.warn(
          "#{self.class}#user= is deprecated and will be removed in Spree 6.5. Use #customer= instead."
        )
      end
      self.customer = value
    end
  end
end
