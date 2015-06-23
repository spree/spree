module Spree
  module Adjustable
    module Adjuster
      class Tax < Spree::Adjustable::Adjuster::Base

        def update
          tax = (adjustable.try(:all_adjustments) || adjustable.adjustments).tax

          included_tax_total = tax.is_included.reload.map(&:update!).compact.sum
          additional_tax_total = tax.additional.reload.map(&:update!).compact.sum

          @totals[:included_tax_total] = included_tax_total
          @totals[:additional_tax_total] = additional_tax_total
          @totals[:adjustment_total] += additional_tax_total
        end

      end
    end
  end
end
