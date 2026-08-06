require 'spec_helper'

describe Spree::TaxProvider::Internal, type: :model do
  subject(:provider) { described_class.new }

  let(:order) { create(:order_with_line_items, line_items_count: 1) }
  let(:line_item) { order.line_items.first }
  let(:zone) do
    create(:zone, kind: 'country', default_tax: true).tap do |zone|
      zone.members.create!(zoneable: order.tax_address.country)
    end
  end

  describe '#estimate' do
    context 'with an additional rate' do
      let!(:rate) { create(:tax_rate, zone: zone, amount: 0.1, tax_category: line_item.tax_category, included_in_price: false) }

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
        expect(tax_line.category_code).to eq('S')
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

      it 'removes lines when the zone stops matching' do
        provider.estimate(order)
        expect(order.tax_lines.reload.count).to eq(1)

        zone.members.delete_all
        allow(order).to receive(:tax_zone).and_return(nil)
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
      let!(:rate) { create(:tax_rate, zone: zone, amount: 0.2, tax_category: line_item.tax_category, included_in_price: true) }

      it 'backs the tax out of the gross basis' do
        provider.estimate(order)

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(1.67)
        expect(tax_line.included).to be(true)
        expect(line_item.reload.pre_tax_amount.round(2)).to eq(8.33)
      end
    end

    context 'with a matched zero rate' do
      let!(:rate) { create(:tax_rate, zone: zone, amount: 0, tax_category: line_item.tax_category, included_in_price: false) }

      it 'still writes a row, marked zero-rated' do
        provider.estimate(order)

        tax_line = order.tax_lines.reload.sole
        expect(tax_line.amount).to eq(0)
        expect(tax_line.taxability_reason).to eq('zero_rated')
        expect(tax_line.category_code).to eq('Z')
        expect(tax_line.tax_rate).to eq(rate)
      end
    end

    context 'with no matching rate' do
      let!(:rate) { create(:tax_rate, zone: zone, amount: 0.1, tax_category: create(:tax_category), included_in_price: false) }

      it 'writes nothing, having formed no opinion' do
        provider.estimate(order)

        expect(order.tax_lines.reload).to be_empty
      end
    end

    context 'when the owner is a cart' do
      let(:cart) { create(:cart_with_line_items, line_items_count: 1, ship_address: create(:address)) }
      let(:cart_line_item) { cart.line_items.first }
      let(:cart_zone) do
        create(:zone, kind: 'country', default_tax: true).tap do |zone|
          zone.members.create!(zoneable: cart.tax_address.country)
        end
      end
      let!(:rate) do
        create(:tax_rate, zone: cart_zone, amount: 0.1, tax_category: cart_line_item.tax_category, included_in_price: false)
      end

      it 'owns the row through the cart FK' do
        provider.estimate(cart)

        tax_line = cart.tax_lines.reload.sole
        expect(tax_line.cart).to eq(cart)
        expect(tax_line.order).to be_nil
        expect(tax_line.taxability_reason).to eq('standard_rated')
      end
    end

    context 'with a taxable fee' do
      let!(:rate) do
        create(:tax_rate, zone: zone, amount: 0.1, tax_category: create(:tax_category, is_default: true), included_in_price: false)
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
