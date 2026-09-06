module Spree
  module Seeds
    # The Wholesale group is a pricing audience: catalog assignments and
    # price lists key off membership. It never activates anyone — whether a
    # company may buy is the activation policy's answer
    # (docs/plans/6.0-b2b-company-self-registration.md).
    class CustomerGroups
      prepend Spree::ServiceModule::Base

      WHOLESALE_NAME = 'Wholesale'.freeze

      def call
        Spree::Store.find_each do |store|
          store.customer_groups.find_or_create_by!(name: WHOLESALE_NAME)
        end
      end
    end
  end
end
