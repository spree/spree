require 'spec_helper'

RSpec.describe Spree::StoreProduct, type: :model do
  describe '#refresh_metrics!' do
    let(:store) { @default_store }
    let(:product) { create(:product, stores: [store]) }
    let(:store_product) { product.store_products.find_by(store: store) }

    context 'when there are no completed orders' do
      it 'sets statistics to zero' do
        store_product.refresh_metrics!

        expect(store_product.units_sold_count).to eq(0)
        expect(store_product.revenue).to eq(0)
      end
    end

    context 'when there are completed orders' do
      let!(:completed_order_1) do
        create(:completed_order_with_totals, store: store, variants: [product.master], line_items_price: 20)
      end

      let!(:completed_order_2) do
        create(:completed_order_with_totals, store: store, variants: [product.master], line_items_price: 30)
      end

      it 'calculates units_sold_count from line item quantities' do
        store_product.refresh_metrics!

        # Each order has 1 line item with quantity 1
        expect(store_product.units_sold_count).to eq(2)
      end

      it 'calculates revenue from line item pre_tax_amount' do
        store_product.refresh_metrics!

        # pre_tax_amount is set by the order creation process
        expected_revenue = completed_order_1.line_items.sum(:pre_tax_amount) +
                          completed_order_2.line_items.sum(:pre_tax_amount)
        expect(store_product.revenue).to eq(expected_revenue)
      end
    end

    context 'when orders are from different stores' do
      let(:other_store) { create(:store) }

      let!(:order_in_store) do
        create(:completed_order_with_totals, store: store, variants: [product.master], line_items_price: 25)
      end

      let!(:order_in_other_store) do
        create(:completed_order_with_totals, store: other_store, variants: [product.master], line_items_price: 100)
      end

      it 'only counts statistics from the specific store' do
        store_product.refresh_metrics!

        expect(store_product.units_sold_count).to eq(1)
        expect(store_product.revenue).to eq(order_in_store.line_items.sum(:pre_tax_amount))
      end
    end

    context 'when orders have multiple line items with different quantities' do
      let!(:completed_order) do
        create(:completed_order_with_totals, store: store, variants: [product.master], line_items_price: 10).tap do |order|
          order.line_items.first.update!(quantity: 3)
        end
      end

      it 'sums quantities for units_sold_count' do
        store_product.refresh_metrics!

        expect(store_product.units_sold_count).to eq(3)
      end

      it 'uses pre_tax_amount for revenue' do
        store_product.refresh_metrics!

        expect(store_product.revenue).to eq(completed_order.line_items.sum(:pre_tax_amount))
      end
    end

    context 'when product has variants' do
      let(:variant) { create(:variant, product: product) }

      let!(:order_with_variant) do
        create(:completed_order_with_totals, store: store, variants: [variant], line_items_price: 15)
      end

      it 'includes orders with product variants in statistics' do
        store_product.refresh_metrics!

        expect(store_product.units_sold_count).to eq(1)
        expect(store_product.revenue).to eq(order_with_variant.line_items.sum(:pre_tax_amount))
      end
    end

    context 'when there are multiple line items across orders' do
      let!(:order_1) do
        create(:completed_order_with_totals, store: store, variants: [product.master], line_items_price: 10).tap do |order|
          order.line_items.first.update!(quantity: 2)
        end
      end

      let!(:order_2) do
        create(:completed_order_with_totals, store: store, variants: [product.master], line_items_price: 15).tap do |order|
          order.line_items.first.update!(quantity: 5)
        end
      end

      it 'sums all quantities across orders' do
        store_product.refresh_metrics!

        expect(store_product.units_sold_count).to eq(7) # 2 + 5
      end

      it 'sums all pre_tax_amounts across orders' do
        store_product.refresh_metrics!

        expected_revenue = order_1.line_items.sum(:pre_tax_amount) + order_2.line_items.sum(:pre_tax_amount)
        expect(store_product.revenue).to eq(expected_revenue)
      end
    end
  end
end
