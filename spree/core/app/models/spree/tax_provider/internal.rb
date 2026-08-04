module Spree
  module TaxProvider
    # Computes tax directly from TaxRate configuration: rate × discounted
    # base, with VAT included-in-price math backed out of the gross basis.
    # Zone matching is unchanged from 5.x (TaxRate.match over the owner's tax
    # zone). Fees without a tax category are taxed with the default tax
    # category's rates.
    class Internal < Base
      def estimate(owner, items = nil)
        items ||= owner.line_items.to_a + owner.fulfillments.to_a + owner.fees.to_a
        return if items.empty?

        rates = Spree::TaxRate.match(owner.tax_zone)

        items.group_by(&:class).each do |klass, group|
          # Replace-all set semantics per estimate: stale lines die with the
          # address/items change that triggered the re-estimate.
          Spree::TaxLine.where(tax_line_foreign_key(klass) => group.map(&:id)).delete_all
        end

        items.each do |item|
          relevant_rates = rates.select { |rate| rate.tax_category_id == tax_category_id_for(item) }
          store_pre_tax_amount(item, relevant_rates)

          relevant_rates.each do |rate|
            amount = compute_tax(rate, item, relevant_rates)
            next if amount.zero?

            write_tax_line(owner, item, rate, amount)
          end
        end
      end

      private

      def tax_line_foreign_key(klass)
        case klass.name
        when 'Spree::LineItem' then :line_item_id
        when 'Spree::Fulfillment' then :fulfillment_id
        when 'Spree::Fee' then :fee_id
        else raise ArgumentError, "#{klass} is not taxable"
        end
      end

      def tax_category_id_for(item)
        if item.respond_to?(:tax_category_id) && item.tax_category_id
          item.tax_category_id
        else
          default_tax_category&.id
        end
      end

      def default_tax_category
        return @default_tax_category if defined?(@default_tax_category)

        @default_tax_category = Spree::TaxCategory.find_by(is_default: true)
      end

      def taxable_basis(item)
        item.respond_to?(:taxable_basis) ? item.taxable_basis : item.amount
      end

      def compute_tax(rate, item, relevant_rates)
        basis = taxable_basis(item)

        if rate.included_in_price
          included_sum = relevant_rates.select(&:included_in_price).sum(&:amount)
          included_sum = rate.amount if included_sum.zero?
          (basis / (1 + included_sum) * rate.amount).round(2)
        else
          (basis * rate.amount).round(2)
        end
      end

      # Pre-tax amounts are stored so refund and reporting code can weigh
      # discounted, tax-exclusive values later (see #4318).
      def store_pre_tax_amount(item, rates)
        return unless item.respond_to?(:pre_tax_amount)

        pre_tax_amount = taxable_basis(item)
        included_rates = rates.select(&:included_in_price)
        pre_tax_amount /= (1 + included_rates.sum(&:amount)) if included_rates.any?

        item.update_column(:pre_tax_amount, pre_tax_amount)
      end

      def write_tax_line(owner, item, rate, amount)
        owner_key = owner.is_a?(Spree::Order) ? :order : :cart
        Spree::TaxLine.create!(
          tax_line_foreign_key(item.class) => item.id,
          owner_key => owner,
          tax_rate: rate,
          amount: amount,
          rate: rate.amount,
          label: rate.adjustment_label,
          included: rate.included_in_price,
          provider_id: 'internal'
        )
      end
    end
  end
end
