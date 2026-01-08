require 'spec_helper'

RSpec.describe Spree::Reports::ProductsPerformance do
  let(:store) { @default_store }
  let(:report) { create(:products_performance_report, store: store) }
  let(:product) { create(:product, stores: [store]) }
  let(:variant) { create(:variant, product: product) }
  let(:order) { create(:completed_order_with_totals, store: store, currency: report.currency) }
  let(:line_item) { create(:line_item, order: order, variant: variant) }

  describe '#line_items_scope' do
    context 'when order is within date range' do
      before do
        order.update(completed_at: report.date_from + 1.day)
        line_item.save!
      end

      it 'includes products with sales data' do
        result = report.line_items_scope.first

        expect(result.pre_tax_amount.to_f).to eq(line_item.pre_tax_amount)
        expect(result.quantity).to eq(line_item.quantity)
        expect(result.promo_total.to_f).to eq(line_item.promo_total)
        expect(result.tax_total.to_f).to eq(line_item.included_tax_total + line_item.additional_tax_total)
        expect(result.total.to_f).to eq(line_item.pre_tax_amount + line_item.adjustment_total)
      end
    end

    context 'when order is outside date range' do
      before do
        order.update(completed_at: report.date_from - 1.day)
      end

      it 'excludes products from orders outside date range' do
        expect(report.line_items_scope).to be_empty
      end
    end

    context 'date range boundary conditions' do
      before { line_item.save! }

      context 'when order completed exactly at date_from' do
        before { order.update(completed_at: report.date_from) }

        it 'includes products' do
          expect(report.line_items_scope).not_to be_empty
        end
      end

      context 'when order completed exactly at date_to' do
        before { order.update(completed_at: report.date_to) }

        it 'includes products' do
          expect(report.line_items_scope).not_to be_empty
        end
      end

      context 'when order completed 1 minute before date_from' do
        before { order.update(completed_at: report.date_from - 1.minute) }

        it 'excludes products' do
          expect(report.line_items_scope).to be_empty
        end
      end

      context 'when order completed 1 minute after date_to' do
        before { order.update(completed_at: report.date_to + 1.minute) }

        it 'excludes products' do
          expect(report.line_items_scope).to be_empty
        end
      end
    end

    context 'when order has different currency' do
      before do
        order.update(currency: 'EUR')
      end

      it 'excludes products with different currency' do
        expect(report.line_items_scope).to be_empty
      end
    end
  end
end
