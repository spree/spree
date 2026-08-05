module Spree
  module Orders
    # @deprecated Use {Spree::Customers::Create}; removed in 6.1. Note that
    #   core no longer sends a welcome email — implement it on the
    #   `user.created` event or the `customers.create.after_create` hook.
    class CreateUserAccount
      def self.call(order:, accepts_email_marketing: false)
        Spree::Deprecation.warn(
          'Spree::Orders::CreateUserAccount is deprecated and will be removed in Spree 6.1. ' \
          'Use Spree::Customers::Create (Spree.customer_create_workflow) instead. ' \
          'Core no longer sends a welcome email — send it from a user.created subscriber or the customers.create.after_create hook.'
        )
        Spree.customer_create_workflow.call(
          store: order.store,
          order: order,
          accepts_email_marketing: accepts_email_marketing.to_b
        )
      end
    end
  end
end
