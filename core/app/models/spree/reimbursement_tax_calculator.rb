module Spree

  # Tax calculation is broken out at this level to allow easy integration with 3rd party
  # taxation systems.  Those systems are usually geared toward calculating all items at once
  # rather than one at a time.
  #
  # To use an alternative tax calculator do this:
  #    Spree::Reimbursement.reimbursement_tax_calculator = calculator_object
  # where `calculator_object` is an object that responds to "call" and accepts a reimbursement object

  class ReimbursementTaxCalculator

    class << self

      def call(reimbursement)
        reimbursement.reimbursement_items.includes(:inventory_unit).each do |reimbursement_item|
          set_tax!(reimbursement_item)
        end
      end

      private

      def set_tax!(reimbursement_item)
        percent_of_tax = (reimbursement_item.pre_tax_amount <= 0) ? 0 : reimbursement_item.pre_tax_amount / reimbursement_item.inventory_unit.pre_tax_amount

        additional_tax_total = percent_of_tax * reimbursement_item.inventory_unit.additional_tax_total
        included_tax_total   = percent_of_tax * reimbursement_item.inventory_unit.included_tax_total

        reimbursement_item.update_attributes!({
          additional_tax_total: additional_tax_total,
          included_tax_total:   included_tax_total,
        })
      end
    end

  end

end
