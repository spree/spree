require 'spec_helper'

RSpec.describe Spree::ReportLineItems::SalesTotal do
  let(:order) { create(:completed_order_with_totals) }
  let(:line_item) { order.line_items.first }
  let(:sales_total) { described_class.new(record: line_item) }

  describe '#date' do
    it 'returns formatted completed_at date' do
      expect(sales_total.date).to eq(order.completed_at.strftime('%Y-%m-%d'))
    end
  end

  describe '#order' do
    it 'returns order number' do
      expect(sales_total.order).to eq(order.number)
    end
  end

  describe '#product' do
    it 'returns variant descriptive name' do
      expect(sales_total.product).to eq(line_item.variant.descriptive_name)
    end
  end

  describe '#quantity' do
    it 'returns quantity' do
      expect(sales_total.quantity).to eq(line_item.quantity)
    end
  end

  describe '#total' do
    it 'returns money object with final amount plus shipping' do
      total = Spree::Money.new(line_item.final_amount + line_item.shipping_cost, currency: line_item.currency)
      expect(sales_total.total).to eq(total)
    end
  end

  describe '#promo_total' do
    it 'returns display promo total' do
      expect(sales_total.promo_total).to eq(line_item.display_promo_total)
    end
  end

  describe '#pre_tax_amount' do
    it 'returns display pre tax amount' do
      expect(sales_total.pre_tax_amount).to eq(line_item.display_pre_tax_amount)
    end
  end

  describe '#shipment_total' do
    it 'returns display shipping cost' do
      expect(sales_total.shipment_total).to eq(line_item.display_shipping_cost)
    end
  end

  describe '#tax_total' do
    it 'returns display tax total' do
      expect(sales_total.tax_total).to eq(line_item.display_tax_total)
    end
  end
end
