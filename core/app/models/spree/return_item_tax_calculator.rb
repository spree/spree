module Spree

  # Tax calculation is broken out at this level to allow easy integration with 3rd party
  # taxation systems.  Those systems are usually geared toward calculating all items at once
  # rather than one at a time.
  #
  # To use an alternative tax calculator do this:
  #    Spree::ReturnAuthorization.return_item_tax_calculator = calculator_object
  # where `calculator_object` is an object that responds to "call" and accepts an array of return items

  class ReturnItemTaxCalculator

    class << self

      def call(return_items)
        return_items.each do |return_item|
          set_tax!(return_item)
        end
      end

      private

      def set_tax!(return_item)
        percent_of_tax = (return_item.pre_tax_amount <= 0) ? 0 : return_item.pre_tax_amount / return_item.inventory_unit.pre_tax_amount

        additional_tax_total = percent_of_tax * return_item.inventory_unit.additional_tax_total
        included_tax_total   = percent_of_tax * return_item.inventory_unit.included_tax_total

        return_item.update_attributes!({
          additional_tax_total: additional_tax_total,
          included_tax_total:   included_tax_total,
        })
      end
    end

  end

end
