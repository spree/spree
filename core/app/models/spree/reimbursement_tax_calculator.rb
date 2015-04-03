module Spree

  # Tax calculation is broken out at this level to allow easy integration with 3rd party
  # taxation systems.  Those systems are usually geared toward calculating all items at once
  # rather than one at a time.
  #
  # To use an alternative tax calculator do this:
  #    Spree::ReturnAuthorization.reimbursement_tax_calculator = calculator_object
  # where `calculator_object` is an object that responds to "call" and accepts a reimbursement object

  class ReimbursementTaxCalculator

    class << self

      def call(reimbursement)
        reimbursement.return_items.includes(:inventory_unit).each do |return_item|
          set_tax!(return_item)
        end
      end

      private

      def set_tax!(return_item)
        calculated_refund = Spree::ReturnItem.refund_amount_calculator.new.compute(return_item)

        return_item.update_attributes!(
          additional_tax_total: return_item.inventory_unit.additional_tax_total,
          included_tax_total: return_item.inventory_unit.included_tax_total
        )
      end
    end

  end

end
