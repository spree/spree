module Spree
  module PaymentMethodRules
    # Offers the method only to customers in one of the listed groups. Guests
    # belong to no group, so a configured rule never offers the method to them.
    class CustomerGroupRule < Spree::PaymentMethodRule
      preference :customer_group_ids, :array, of: :id, model: 'Spree::CustomerGroup', default: [],
                 scope: ->(rule) { rule.store.customer_groups }

      def eligible?(purchase)
        return true if preferred_customer_group_ids.empty?
        return false if purchase.customer.nil?

        Spree::CustomerGroupUser.where(customer: purchase.customer, customer_group_id: preferred_customer_group_ids).exists?
      end
    end
  end
end
