require 'spec_helper'

RSpec.describe Spree::CSV::OrderLineItemPresenter do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:line_item) { order.line_items.first }
  let(:index) { 0 }
  let(:presenter) { described_class.new(order, line_item, index) }

  describe '#call' do
    subject { presenter.call }

    it 'returns array with correct values' do
      expect(subject[0]).to eq order.number
      expect(subject[1]).to eq order.email
      expect(subject[2]).to eq order.state
      expect(subject[3]).to eq order.currency
      expect(subject[4]).to eq order.item_total.to_f
      expect(subject[5]).to eq order.shipment_total.to_f
      expect(subject[6]).to eq order.tax_total.to_f
      expect(subject[7]).to eq order.included_tax_total.positive?
      expect(subject[8]).to eq(order.promo_total.negative? || line_item.promo_total.negative?)
      expect(subject[9]).to eq order.has_free_shipping?
      expect(subject[10]).to eq order.promo_total.abs
      expect(subject[11]).to eq order.promo_code
      expect(subject[12]).to eq order.payments.store_credits.sum(:amount).abs
      expect(subject[13]).to eq order.total.to_f
      expect(subject[17]).to eq line_item.product_id
      expect(subject[18]).to eq line_item.quantity
      expect(subject[19]).to eq line_item.sku
      expect(subject[20]).to eq line_item.name
      expect(subject[21]).to eq line_item.price
      expect(subject[22]).to eq line_item.promo_total.abs
      expect(subject[23]).to eq line_item.total
    end

    context 'when index is not zero' do
      let(:index) { 1 }

      it 'returns nil for order-level fields' do
        expect(subject[1]).to be_nil # email
        expect(subject[2]).to be_nil # state
        expect(subject[3]).to be_nil # currency
        expect(subject[4]).to be_nil # item_total
      end

      it 'returns line item specific fields' do
        expect(subject[17]).to eq line_item.product_id
        expect(subject[18]).to eq line_item.quantity
        expect(subject[19]).to eq line_item.sku
      end
    end
  end

  describe '#taxon_dict' do
    let(:taxon) { build(:taxon, pretty_name: 'Category -> Subcategory -> Product') }

    it 'splits taxon pretty name into array' do
      expect(presenter.send(:taxon_dict, taxon)).to eq(['Category', 'Subcategory', 'Product'])
    end

    it 'returns empty array for nil taxon' do
      expect(presenter.send(:taxon_dict, nil)).to eq([])
    end
  end

  describe '#format_date' do
    let(:date) { Time.current }

    it 'formats date according to store timezone' do
      expect(presenter.send(:format_date, date)).to eq(
        date.in_time_zone(order.store.preferred_timezone).strftime('%Y-%m-%d %H:%M:%S')
      )
    end

    it 'returns nil for blank date' do
      expect(presenter.send(:format_date, nil)).to be_nil
    end
  end
end
