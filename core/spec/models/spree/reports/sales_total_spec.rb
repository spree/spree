require 'spec_helper'

RSpec.describe Spree::Reports::SalesTotal do
  let(:store) { @default_store }
  let(:report) { create(:report, store: store) }
  let(:order) { create(:completed_order_with_totals, store: store, currency: report.currency) }
  let!(:line_item) { order.line_items.first }

  describe '#line_items_scope' do
    context 'when order is within date range' do
      before do
        order.update(completed_at: report.date_from + 1.day)
      end

      it 'includes line items from completed orders within date range' do
        expect(report.line_items_scope).to include(line_item)
      end
    end

    context 'when order is outside date range' do
      before do
        order.update(completed_at: report.date_from - 1.day)
      end

      it 'excludes line items from orders outside date range' do
        expect(report.line_items_scope).not_to include(line_item)
      end
    end

    context 'when order has different currency' do
      before do
        order.update(currency: 'EUR')
      end

      it 'excludes line items with different currency' do
        expect(report.line_items_scope).not_to include(line_item)
      end
    end

    context 'when order is incomplete' do
      before do
        order.update(completed_at: nil)
      end

      it 'excludes line items from incomplete orders' do
        expect(report.line_items_scope).not_to include(line_item)
      end
    end
  end

  describe '#return_line_items' do
    let(:return_line_item) { report.line_items.first }

    it 'returns line items' do
      expect(return_line_item).to be_a(Spree::ReportLineItems::SalesTotal)

      expect(return_line_item.date).to eq(order.completed_at.strftime('%Y-%m-%d'))
      expect(return_line_item.order).to eq(order.number)
      expect(return_line_item.product).to eq(line_item.variant.descriptive_name)
      expect(return_line_item.quantity).to eq(line_item.quantity)
      expect(return_line_item.tax_total).to eq(line_item.display_tax_total)
      expect(return_line_item.promo_total).to eq(line_item.display_promo_total)
      expect(return_line_item.pre_tax_amount).to eq(line_item.display_pre_tax_amount)
      expect(return_line_item.shipment_total).to eq(line_item.display_shipping_cost)
    end
  end
end
