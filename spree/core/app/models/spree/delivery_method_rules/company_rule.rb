module Spree
  module DeliveryMethodRules
    # Splits freight from parcel by who is buying.
    #
    # On, the method is offered only to orders placed for a company — a
    # carton or container tier disappears from retail carts. Off, it is
    # offered only to orders that are not, which is how a merchant keeps
    # parcel methods away from wholesale buyers. A method with no company
    # rule at all is offered to both, so the rule is only ever added to
    # state a split.
    #
    # Presence only. Which company gets which freight terms is Enterprise
    # territory, and open-source Spree has no company roles to gate on.
    class CompanyRule < Spree::DeliveryMethodRule
      preference :company_orders_only, :boolean, default: true

      def eligible?(package)
        buying_for_a_company = package.owner&.b2b? || false

        preferred_company_orders_only ? buying_for_a_company : !buying_for_a_company
      end
    end
  end
end
