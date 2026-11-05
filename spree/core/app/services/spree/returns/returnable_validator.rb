module Spree
  module Returns
    # Customers send back only what reached them and was sold as returnable.
    #
    # A unit must belong to a fulfillment that has shipped, and its line item
    # must carry `returnable`, which is frozen from the variant when the order
    # is placed — so a product marked final sale after the sale does not take
    # back a right already granted (docs/plans/6.1-returns-portal.md). This is
    # where a store states the EU exemptions for sealed, personalised or
    # perishable goods (Consumer Rights Directive Art. 16).
    #
    # Advisory for staff, like the return window: a merchant may still take
    # back a final-sale item for a good customer.
    class ReturnableValidator < UnitValidator
      # @param workflow [Spree::Returns::Create, Spree::Exchanges::Create]
      def call(workflow)
        return if workflow.created_by.present?

        units = units_of(workflow)

        unshipped = units.reject { |unit| unit.fulfillment&.fulfilled_or_delivered? }
        refuse(workflow, :not_shipped, unshipped) if unshipped.any?

        final_sale = units.reject(&:returnable?)
        refuse(workflow, :not_returnable, final_sale) if final_sale.any?
      end
    end
  end
end
