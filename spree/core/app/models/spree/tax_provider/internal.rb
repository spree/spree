module Spree
  module TaxProvider
    # Computes tax directly from TaxRate configuration: rate × discounted
    # base, with VAT included-in-price math backed out of the gross basis.
    # Zone matching is unchanged from 5.x (TaxRate.match over the owner's tax
    # zone). Fees without a tax category are taxed with the default tax
    # category's rates.
    class Internal < Base
      # Rates are configured per zone with no local-tax breakdown, no buyer
      # registration handling and no distance-selling thresholds. Declared so a
      # merchant pairing this with a market is told, rather than discovering it
      # in a return.
      def self.unsupported_capabilities
        %i[us_local_tax reverse_charge oss_thresholds]
      end

      # +tax_date+ is accepted and ignored: TaxRate rows carry no validity
      # period, so there is only ever one version of the configuration to read.
      # +tax_identifier+ likewise — reverse charge is on the unsupported list,
      # so a buyer registration changes nothing here.
      def estimate(owner, items = nil, tax_date: nil, tax_identifier: nil, exemptions: [], context: {})
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

          # A matched rate always produces a row, zero-amount ones included:
          # a zero rate is a treatment ("this is zero-rated"), which reporting
          # and e-invoicing both need to see. No matched rate means no opinion,
          # and writes nothing.
          relevant_rates.each do |rate|
            amount = compute_tax(rate, item, relevant_rates)
            write_tax_line(owner, item, rate, amount, reason_for(rate))
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

      # Finer distinctions — a reduced rate, an exempt supply — are a matter of
      # rate configuration rather than something to infer from the number.
      def reason_for(rate)
        rate.amount.to_d.zero? ? 'zero_rated' : 'standard_rated'
      end

      # The jurisdiction that taxed the line. Read from the owner's tax address
      # rather than its tax zone, because a Zone can span several countries and
      # so has no single country to report. Rates carry their own country from
      # the tax-side Zone decoupling onwards.
      def jurisdiction_for(owner)
        address = owner.tax_address
        return {} if address.nil?

        { country_iso: address.country&.iso, state_code: address.state&.abbr }
      end

      def write_tax_line(owner, item, rate, amount, reason)
        owner_key = owner.is_a?(Spree::Order) ? :order : :cart
        Spree::TaxLine.create!(
          {
            tax_line_foreign_key(item.class) => item.id,
            owner_key => owner,
            tax_rate: rate,
            amount: amount,
            rate: rate.amount,
            label: rate.adjustment_label,
            included: rate.included_in_price,
            provider_id: 'internal',
            taxability_reason: reason
          }.merge(jurisdiction_for(owner))
        )
      end
    end
  end
end
