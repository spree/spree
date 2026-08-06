require 'spec_helper'

describe Spree::TaxProvider::Internal, type: :model do
  subject(:provider) { described_class.new }

  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:line_item) { order.line_items.first }
  # Rates name their country directly since 6.0 — the order's own tax address.
  let(:country) { order.tax_address.country }

  describe '#estimate' do
    context 'with an additional rate' do
      let!(:rate) { create(:tax_rate, country: country, amount: 0.1, tax_category: line_item.tax_category, included_in_price: false) }

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
        expect(tax_line.country_iso).to eq(order.tax_address.country.iso)
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

        rate.update!(country: create(:country, iso: 'JP', name: 'Japan'))
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
      let!(:rate) { create(:tax_rate, country: country, amount: 0.2, tax_category: line_item.tax_category, included_in_price: true) }

      it 'backs the tax out of the gross basis' do
        provider.estimate(order)

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(1.67)
        expect(tax_line.included).to be(true)
        expect(line_item.reload.pre_tax_amount.round(2)).to eq(8.33)
      end
    end

    context 'with a matched zero rate' do
      let!(:rate) { create(:tax_rate, country: country, amount: 0, tax_category: line_item.tax_category, included_in_price: false) }

      it 'still writes a row, marked zero-rated' do
        provider.estimate(order)

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(0)
        expect(tax_line.taxability_reason).to eq('zero_rated')
        expect(tax_line.tax_rate).to eq(rate)
      end
    end

    context 'with no matching rate' do
      let!(:rate) { create(:tax_rate, country: country, amount: 0.1, tax_category: create(:tax_category), included_in_price: false) }

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
        create(:tax_rate, country: cart_country, amount: 0.1, tax_category: cart_line_item.tax_category, included_in_price: false)
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
      let!(:rate) { create(:tax_rate, country: country, amount: 0.1, tax_category: line_item.tax_category, included_in_price: false) }
      let(:exemption) { Spree::TaxExemption.new(reason_code: 'resale', certificate_number: 'CERT-1') }

      it 'writes a zero row recording the claim' do
        provider.estimate(order, exemptions: [exemption])

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(0)
        expect(tax_line.taxability_reason).to eq('customer_exempt')
        expect(tax_line.data['exemption']).to eq('reason_code' => 'resale', 'certificate_number' => 'CERT-1')
      end

      it 'ignores an exemption scoped to another jurisdiction' do
        elsewhere = Spree::TaxExemption.new(reason_code: 'resale', country_iso: 'DE')

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

    context 'with an exemption against an included (VAT) rate' do
      let!(:rate) { create(:tax_rate, country: country, amount: 0.2, tax_category: line_item.tax_category, included_in_price: true) }

      it 'leaves the whole basis pre-tax, having no tax to back out' do
        provider.estimate(order, exemptions: [Spree::TaxExemption.new(reason_code: 'government')])

        expect(order.tax_lines.reload.sole.amount).to eq(0)
        expect(line_item.reload.pre_tax_amount).to eq(10)
      end
    end

    context 'when another store holds the default tax category' do
      let!(:rate) do
        create(:tax_rate, country: country, amount: 0.1,
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

    context 'with a taxable fee' do
      let!(:rate) do
        create(:tax_rate, country: country, amount: 0.1, tax_category: create(:tax_category, is_default: true), included_in_price: false)
      end
      let!(:fee) { create(:fee, order: order, amount: 5, kind: 'surcharge', label: 'Handling') }

      it 'writes a tax line against the fee using the default tax category' do
        provider.estimate(order, [fee])

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.fee).to eq(fee)
        expect(tax_line.amount).to eq(0.5)
      end
    end
  end
end
