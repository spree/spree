module Spree
  module TaxProvider
    # Computes tax directly from TaxRate configuration: rate × discounted
    # base, with VAT included-in-price math backed out of the gross basis.
    # Rates are matched on the owner's tax address, each naming its own country
    # and optionally a state. Fees without a tax category are taxed with the
    # default tax category's rates.
    class Internal < Base
      # Rates are configured per country or state with no local-tax breakdown, no buyer
      # registration handling, no distance-selling thresholds, and delivery taxed
      # at its own method's rate rather than apportioned across the rates of the
      # goods it carries. Declared so a merchant pairing this with a market is
      # told, rather than discovering it in a return.
      def self.unsupported_capabilities
        %i[us_local_tax reverse_charge oss_thresholds proportional_delivery_tax]
      end

      # +tax_date+ is accepted and ignored: TaxRate rows carry no validity
      # period, so there is only ever one version of the configuration to read.
      # +tax_identifier+ likewise — reverse charge is on the unsupported list,
      # so a buyer registration changes nothing here.
      def estimate(owner, items = nil, tax_date: nil, tax_identifier: nil, exemptions: [], context: {})
        items ||= owner.line_items.to_a + owner.fulfillments.to_a + owner.fees.to_a
        return if items.empty?

        rates = Spree::TaxRate.for_store(owner.store).for_jurisdiction(owner.tax_country&.iso, owner.tax_address&.state_code).to_a

        items.group_by(&:class).each do |klass, group|
          # Replace-all set semantics per estimate: stale lines die with the
          # address/items change that triggered the re-estimate.
          Spree::TaxLine.where(tax_line_foreign_key(klass) => group.map(&:id)).delete_all
        end

        items.each do |item|
          relevant_rates = rates.select { |rate| rate.tax_category_id == tax_category_id_for(item, owner) }

          # A matched rate always produces a row, zero-amount ones included:
          # a zero rate is a treatment ("this is zero-rated"), which reporting
          # and e-invoicing both need to see. No matched rate means no opinion,
          # and writes nothing.
          taxed = relevant_rates.map do |rate|
            jurisdiction = jurisdiction_for(rate, owner)
            [rate, jurisdiction, exemption_for(item, exemptions, jurisdiction)]
          end

          # An exempt item has no tax to back out of its price, so its whole
          # basis is pre-tax.
          exempt_rates = taxed.select { |_rate, _jurisdiction, exemption| exemption }.map(&:first)
          store_pre_tax_amount(item, relevant_rates - exempt_rates)

          taxed.each do |rate, jurisdiction, exemption|
            if exemption
              write_tax_line(owner, item, rate, 0, 'customer_exempt', jurisdiction,
                             data: exemption_data(exemption, item))
            else
              write_tax_line(owner, item, rate, compute_tax(rate, item, relevant_rates),
                             reason_for(rate), jurisdiction)
            end
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

      def tax_category_id_for(item, owner)
        if item.respond_to?(:tax_category_id) && item.tax_category_id
          item.tax_category_id
        else
          default_tax_category(owner)&.id
        end
      end

      # The owner's store's default, not any store's: defaults are per store
      # since 6.0, and a foreign category id would match none of this store's
      # rates, silently leaving the item untaxed.
      def default_tax_category(owner)
        return @default_tax_category if defined?(@default_tax_category)

        @default_tax_category = Spree::TaxCategory.default(owner.store)
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

      # The jurisdiction that taxed the line, read off the rate that matched.
      # A rate covering every country falls back to the address, so the row can
      # still say where the sale was taxed.
      def jurisdiction_for(rate, owner)
        {
          country_iso: rate.country_iso.presence || owner.tax_country&.iso,
          state_code: rate.state_code.presence || owner.tax_address&.state_code
        }
      end

      # The first exemption entry that claims both this item and the
      # jurisdiction being taxed. Multiple certificates mean multiple entries,
      # and one claim is enough.
      def exemption_for(item, exemptions, jurisdiction)
        Array(exemptions).find do |exemption|
          exemption.covers_item?(item) &&
            exemption.covers_jurisdiction?(jurisdiction[:country_iso], jurisdiction[:state_code])
        end
      end

      # Keeps the claim with the row it produced: the invoice exemption code for
      # a genuinely exempt supply depends on which exemption applied, which the
      # reason alone cannot say.
      def exemption_data(exemption, item)
        {
          'exemption' => {
            'reason_code' => exemption.reason_code_for(item),
            'certificate_number' => exemption.certificate_number
          }.compact
        }
      end

      def write_tax_line(owner, item, rate, amount, reason, jurisdiction, data: {})
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
            taxability_reason: reason,
            data: data
          }.merge(jurisdiction)
        )
      end
    end
  end
end
