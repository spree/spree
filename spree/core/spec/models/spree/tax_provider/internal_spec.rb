require 'spec_helper'

describe Spree::TaxProvider::Internal, type: :model do
  subject(:provider) { described_class.new }

  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:line_item) { order.line_items.first }
  # Rates name their country directly since 6.0 — the order's own tax address.
  let(:country) { order.tax_address.country }

  describe '#estimate' do
    context 'with an additional rate' do
      let!(:rate) { create(:tax_rate, country_code: country&.iso, amount: 0.1, tax_category: line_item.tax_category, included_in_price: false) }

      it 'writes a tax line with snapshots' do
        provider.estimate(order)

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(1.0)
        expect(tax_line.rate).to eq(0.1)
        expect(tax_line.included).to be(false)
        expect(tax_line.provider_id).to eq('internal')
        expect(tax_line.tax_rate).to eq(rate)
        expect(tax_line.line_item).to eq(line_item)
      end

      it 'stamps the treatment and the taxing jurisdiction' do
        provider.estimate(order)

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.taxability_reason).to eq('standard_rated')
        expect(tax_line.country_code).to eq(order.tax_address.country.iso)
        expect(tax_line.state_code).to eq(order.tax_address.state&.abbr)
      end

      it 'stores the pre-tax amount' do
        provider.estimate(order)
        expect(line_item.reload.pre_tax_amount).to eq(10)
      end

      it 'replaces stale lines on re-estimate' do
        provider.estimate(order)
        first_ids = order.tax_lines.reload.ids

        provider.estimate(order)
        expect(order.tax_lines.reload.ids).not_to eq(first_ids)
        expect(order.tax_lines.count).to eq(1)
      end

      it 'removes lines when the rate stops covering the destination' do
        provider.estimate(order)
        expect(order.tax_lines.reload.count).to eq(1)

        rate.update!(country_code: 'JP')
        provider.estimate(order)
        expect(order.tax_lines.reload).to be_empty
      end

      it 'estimates on the discounted base' do
        create(:discount, order: order, line_item: line_item, amount: -5, kind: 'manual')
        line_item.update_column(:taxable_adjustment_total, -5)

        provider.estimate(order)
        expect(order.tax_lines.reload.sole.amount).to eq(0.5)
      end
    end

    context 'with an included (VAT) rate' do
      let!(:rate) { create(:tax_rate, country_code: country&.iso, amount: 0.2, tax_category: line_item.tax_category, included_in_price: true) }

      it 'backs the tax out of the gross basis' do
        provider.estimate(order)

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(1.67)
        expect(tax_line.included).to be(true)
        expect(line_item.reload.pre_tax_amount.round(2)).to eq(8.33)
      end
    end

    context 'with a matched zero rate' do
      let!(:rate) { create(:tax_rate, country_code: country&.iso, amount: 0, tax_category: line_item.tax_category, included_in_price: false) }

      it 'still writes a row, marked zero-rated' do
        provider.estimate(order)

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(0)
        expect(tax_line.taxability_reason).to eq('zero_rated')
        expect(tax_line.tax_rate).to eq(rate)
      end
    end

    context 'with no matching rate' do
      let!(:rate) { create(:tax_rate, country_code: country&.iso, amount: 0.1, tax_category: create(:tax_category), included_in_price: false) }

      it 'writes nothing, having formed no opinion' do
        provider.estimate(order)

        expect(order.tax_lines.reload).to be_empty
      end
    end

    context 'when the owner is a cart' do
      let(:cart) { create(:cart_with_line_items, line_items_count: 1, ship_address: create(:address)) }
      let(:cart_line_item) { cart.line_items.first }
      let(:cart_country) { cart.tax_address.country }
      let!(:rate) do
        create(:tax_rate, country_code: cart_country&.iso, amount: 0.1, tax_category: cart_line_item.tax_category, included_in_price: false)
      end

      it 'owns the row through the cart FK' do
        provider.estimate(cart)

        tax_line = cart.tax_lines.reload.sole
        expect(tax_line.cart).to eq(cart)
        expect(tax_line.order).to be_nil
        expect(tax_line.taxability_reason).to eq('standard_rated')
      end
    end

    context 'with an exemption covering the sale' do
      let!(:rate) { create(:tax_rate, country_code: country&.iso, amount: 0.1, tax_category: line_item.tax_category, included_in_price: false) }
      let(:exemption) { Spree::TaxExemption.new(reason_code: 'resale', certificate_number: 'CERT-1') }

      it 'writes a zero row recording the claim' do
        provider.estimate(order, exemptions: [exemption])

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(0)
        expect(tax_line.taxability_reason).to eq('customer_exempt')
        expect(tax_line.data['exemption']).to eq('reason_code' => 'resale', 'certificate_number' => 'CERT-1')
      end

      it 'ignores an exemption scoped to another jurisdiction' do
        elsewhere = Spree::TaxExemption.new(reason_code: 'resale', country_code: 'DE')

        provider.estimate(order, exemptions: [elsewhere])

        expect(order.tax_lines.reload.sole.amount).to eq(1.0)
      end

      it 'taxes a line the buyer carved out for their own use' do
        carved_out = Spree::TaxExemption.new(
          reason_code: 'resale',
          item_overrides: [Spree::TaxExemption::ItemOverride.new(item_id: line_item.prefixed_id, exempt: false)]
        )

        provider.estimate(order, exemptions: [carved_out])

        expect(order.tax_lines.reload.sole.taxability_reason).to eq('standard_rated')
      end
    end

    # The whole chain: a certificate the company holds, resolved by the real
    # service, reaching the provider as a claim.
    context 'with a certificate the buyer company holds' do
      let!(:rate) { create(:tax_rate, country_code: country&.iso, amount: 0.1, tax_category: line_item.tax_category, included_in_price: false) }
      let(:company) { create(:company, store: @default_store) }

      before { order.update!(company: company) }

      def resolved_exemptions
        Spree.tax_resolve_exemptions_service.new.call(order: order.reload).value
      end

      it 'exempts the sale instead of taxing it' do
        create(:tax_exemption_certificate, :verified, company: company,
                                                      reason_code: 'resale', certificate_number: 'CERT-9',
                                                      country_code: country&.iso)

        provider.estimate(order, exemptions: resolved_exemptions)

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(0)
        expect(tax_line.taxability_reason).to eq('customer_exempt')
        expect(tax_line.data['exemption']).to eq('reason_code' => 'resale', 'certificate_number' => 'CERT-9')
      end

      it 'taxes normally while the certificate is still awaiting verification' do
        create(:tax_exemption_certificate, company: company, country_code: country&.iso)

        provider.estimate(order, exemptions: resolved_exemptions)

        expect(order.tax_lines.reload.sole.amount).to eq(1.0)
      end
    end

    context 'with an exemption against an included (VAT) rate' do
      let!(:rate) { create(:tax_rate, country_code: country&.iso, amount: 0.2, tax_category: line_item.tax_category, included_in_price: true) }

      it 'leaves the whole basis pre-tax, having no tax to back out' do
        provider.estimate(order, exemptions: [Spree::TaxExemption.new(reason_code: 'government')])

        expect(order.tax_lines.reload.sole.amount).to eq(0)
        expect(line_item.reload.pre_tax_amount).to eq(10)
      end
    end

    context 'when another store holds the default tax category' do
      let!(:rate) do
        create(:tax_rate, country_code: country&.iso, amount: 0.1,
                          tax_category: create(:tax_category, is_default: true), included_in_price: false)
      end
      let!(:fee) { create(:fee, order: order, amount: 5, kind: 'surcharge', label: 'Handling') }

      it 'reads its own store default rather than any store default' do
        other_store = create(:store)
        Spree::Current.store = other_store
        create(:tax_category, store: other_store, is_default: true)
        Spree::Current.store = nil

        provider.estimate(order, [fee])

        expect(order.tax_lines.reload.sole.amount).to eq(0.5)
      end
    end

    context 'with a classified delivery charge' do
      let(:fulfillment) { order.fulfillments.first }
      let(:reduced_rate_category) { create(:tax_category, name: "Reduced #{Time.current.to_f}") }
      let(:delivery_method) { create(:shipping_method, tax_category: reduced_rate_category) }

      before do
        fulfillment.delivery_rates.destroy_all
        create(:delivery_rate, fulfillment: fulfillment, delivery_method: delivery_method, selected: true)
        # update_columns: the cost is the tax basis here, not an occasion to
        # recalculate the order and estimate tax a second time.
        fulfillment.update_columns(cost: 10)
        # A store default exists, so falling back to it is a visible wrong answer.
        create(:tax_rate, country_code: country&.iso, amount: 0.2, included_in_price: false,
                          tax_category: create(:tax_category, is_default: true))
        fulfillment.reload
      end

      it "taxes delivery at its delivery method's category" do
        reduced_rate = create(:tax_rate, country_code: country&.iso, amount: 0.05, included_in_price: false,
                                         tax_category: reduced_rate_category)

        provider.estimate(order, [fulfillment])

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.fulfillment).to eq(fulfillment)
        expect(tax_line.tax_rate).to eq(reduced_rate)
        expect(tax_line.amount).to eq(0.5)
      end

      # The classification is the merchant's answer even where they configured no
      # rate for it. Taxing delivery at the default category's standard rate
      # instead would over-collect with nothing to show it happened.
      it 'writes no delivery tax when no rate covers that classification' do
        provider.estimate(order, [fulfillment])

        expect(order.tax_lines.reload).to be_empty
      end
    end

    context 'with a taxable fee' do
      let!(:rate) do
        create(:tax_rate, country_code: country&.iso, amount: 0.1, tax_category: create(:tax_category, is_default: true), included_in_price: false)
      end
      let!(:fee) { create(:fee, order: order, amount: 5, kind: 'surcharge', label: 'Handling') }

      it 'writes a tax line against the fee using the default tax category' do
        provider.estimate(order, [fee])

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.fee).to eq(fee)
        expect(tax_line.amount).to eq(0.5)
      end
    end

    context 'with a customs duty' do
      let!(:rate) do
        create(:tax_rate, country_code: country&.iso, amount: 0.1, tax_category: create(:tax_category, is_default: true), included_in_price: false)
      end
      let!(:duty) { create(:fee, order: order, amount: 20, kind: 'duty', label: 'Import duty') }

      it 'leaves the duty untaxed — an import charge is not a taxable supply' do
        provider.estimate(order)

        expect(order.tax_lines.reload.where.not(fee_id: nil)).to be_empty
      end

      it 'still taxes the other fees on the same order' do
        surcharge = create(:fee, order: order, amount: 5, kind: 'surcharge', label: 'Handling')

        provider.estimate(order)

        taxed_fee_ids = order.tax_lines.reload.where.not(fee_id: nil).pluck(:fee_id)
        expect(taxed_fee_ids).to contain_exactly(surcharge.id)
      end

      # Import VAT is levied on the duty in most regimes, so a landed-cost
      # provider must still be able to tax one by naming it explicitly.
      it 'taxes a duty a caller passes explicitly' do
        provider.estimate(order, [duty])

        expect(order.tax_lines.reload.sole.fee).to eq(duty)
      end

      # Duties are absent from the default set, so the per-item cleanup never
      # revisits them — without an explicit sweep a row written once would
      # inflate the total for the life of the order.
      it 'clears a duty tax line it wrote earlier once the duty is excluded again' do
        provider.estimate(order, [duty])
        expect(order.tax_lines.reload.where(fee_id: duty.id)).to be_present

        provider.estimate(order)

        expect(order.tax_lines.reload.where(fee_id: duty.id)).to be_empty
      end

      it 'leaves import VAT another provider wrote on the duty alone' do
        create(:tax_line, order: order, fee: duty, line_item: nil, provider_id: 'landed_cost', amount: 4)

        provider.estimate(order)

        expect(order.tax_lines.reload.where(fee_id: duty.id).pluck(:provider_id)).to eq(['landed_cost'])
      end
    end
  end

  describe '#estimate_refund' do
    let(:order) { create(:shipped_order, line_items_count: 1, line_items_price: 25) }
    let(:line_item) { order.line_items.first }
    let(:return_record) { create(:return, order: order, store: order.store) }
    let(:line) { return_record.return_line_items.first }

    def charge(amount, **attributes)
      create(:tax_line, line_item: line_item, order: order, amount: amount, **attributes)
    end

    def credits(item = line)
      item.tax_lines.credits.order(:id)
    end

    it 'gives back the unit its share of every row the sale charged, row by row' do
      line_item.update_columns(quantity: 2)
      state = charge(2.0, rate: 0.04, label: 'NY State')
      city = charge(2.25, rate: 0.045, label: 'NYC', country_code: 'US', state_code: 'NY')

      provider.estimate_refund(order, [line])

      expect(credits.map(&:amount)).to eq([1.0, 1.13])
      expect(credits.map(&:original_tax_line)).to eq([state, city])
      expect(credits.last).to have_attributes(rate: 0.045, label: 'NYC', provider_id: 'internal',
                                              included: false, country_code: 'US', state_code: 'NY', order: order)
    end

    # Rounding each unit on its own would credit 2.26 of the city's 2.25.
    it 'never gives a row back past what earlier credits left of it' do
      line_item.update_columns(quantity: 2)
      charge(2.0, rate: 0.04)
      charge(2.25, rate: 0.045)
      provider.estimate_refund(order, [line])

      second = create(:return, order: order, store: order.store).return_line_items.first
      provider.estimate_refund(order, [second])

      expect(credits(second).map(&:amount)).to eq([1.0, 1.12])
      expect(Spree::TaxLine.credits.sum(:amount)).to eq(4.25)
    end

    it 'repeats a zero-rated treatment as a zero credit' do
      charge(0, rate: 0, taxability_reason: 'zero_rated')

      provider.estimate_refund(order, [line])

      expect(credits.sole).to have_attributes(amount: 0, taxability_reason: 'zero_rated')
    end

    it 'replaces its own rows rather than adding to them' do
      charge(2.5, rate: 0.1)

      2.times { provider.estimate_refund(order, [line]) }

      expect(credits.sole.amount).to eq(2.5)
    end

    it 'writes nothing for a line that gives no units back' do
      charge(2.5, rate: 0.1)
      provider.estimate_refund(order, [line])
      return_record.update!(status: 'canceled')

      provider.estimate_refund(order, [line])

      expect(credits).to be_empty
    end

    # A restocking fee kept: half the money goes back, so half the tax does.
    it 'gives back only the share of the tax the refunded money carries' do
      charge(2.5, rate: 0.1)

      provider.estimate_refund(order, [line], amounts: { line => line.credited_worth / 2 })

      expect(credits.sole.amount).to eq(1.25)
    end

    it 'leaves the sale rows as they were' do
      sale = charge(2.5, rate: 0.1)

      provider.estimate_refund(order, [line])

      expect(order.tax_lines.reload).to eq([sale])
      expect(sale.reload.amount).to eq(2.5)
    end
  end

  describe '#estimate_replacement' do
    let(:exchange) { create(:exchange) }
    let(:order) { exchange.order }
    let(:line) { exchange.exchange_line_items.first }
    let!(:rate) do
      create(:tax_rate, country_code: order.tax_address.country.iso, amount: 0.2,
                        tax_category: line.new_variant.tax_category, included_in_price: true)
    end

    it 'taxes the replacement as a sale of its own' do
      provider.estimate_replacement(order, [line])

      row = line.tax_lines.charges.sole
      expect(row.amount).to eq((line.taxable_basis / 1.2 * 0.2).round(2))
      expect(row).to have_attributes(included: true, tax_rate: rate, order: order, credit: false)
      expect(order.tax_lines.reload).to be_empty
    end

    it 'leaves the credit for the units coming back alone' do
      credit = create(:tax_line, order: order, line_item: nil, exchange_line_item: line, credit: true, amount: 1)

      provider.estimate_replacement(order, [line])

      expect(line.tax_lines.credits).to eq([credit])
    end

    it 'writes nothing once the exchange is canceled' do
      provider.estimate_replacement(order, [line])
      exchange.update!(status: 'canceled')

      provider.estimate_replacement(order, [line])

      expect(line.tax_lines.reload).to be_empty
    end

    # The carve-out names the line being replaced, which is the line whose
    # treatment the replacement takes over.
    it 'taxes the replacement of a line the buyer carved out of an exemption' do
      carved_out = Spree::TaxExemption.new(
        reason_code: 'resale',
        item_overrides: [Spree::TaxExemption::ItemOverride.new(item_id: line.line_item.prefixed_id, exempt: false)]
      )

      provider.estimate_replacement(order, [line], exemptions: [carved_out])

      expect(line.tax_lines.charges.sole.taxability_reason).to eq('standard_rated')
    end
  end
end
