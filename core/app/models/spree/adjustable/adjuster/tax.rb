module Spree
  module Adjustable
    module Adjuster
      class Tax < Spree::Adjustable::Adjuster::Base
        def update
          tax_adjustments = adjustments.to_a.find_all(&:tax?)
          included_tax_total = tax_adjustments.find_all(&:included?).map(&:update!).compact.sum || 0
          additional_tax_total = tax_adjustments.find_all(&:additional?).map(&:update!).compact.sum || 0

          update_totals(included_tax_total, additional_tax_total)
        end

        private

        def adjustments
          adjustable.try(:all_adjustments) || adjustable.adjustments
        end

        def update_totals(included_tax_total, additional_tax_total)
          @totals[:included_tax_total] = included_tax_total
          @totals[:additional_tax_total] = additional_tax_total
        end
      end
    end
  end
end
