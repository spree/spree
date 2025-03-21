require 'spec_helper'

describe Spree::CheckoutHelper do
  describe '#quick_checkout_enabled?' do
    let(:digital_shipping_method) { create(:digital_shipping_method) }
    let(:digital_product) { create(:product, shipping_category: digital_shipping_method.shipping_categories.first) }
    let(:digital_variant) { create(:variant, product: digital_product, digitals: [create(:digital)]) }
    let(:digital_line_item) { create(:line_item, variant: digital_variant, quantity: 1, order: order) }
    let(:physical_line_item) { create(:line_item, quantity: 1, order: order) }
    let(:order) { create(:order) }

    it 'returns true if the order is fully digital' do
      digital_line_item
      order.update_totals

      expect(helper.quick_checkout_enabled?(order)).to be true
    end

    it 'returns true if the order has no digital products at all' do
      physical_line_item
      order.update_totals

      expect(helper.quick_checkout_enabled?(order)).to be true
    end

    it 'returns false if the order has physical products and some digital products' do
      physical_line_item
      digital_line_item
      order.update_totals

      expect(helper.quick_checkout_enabled?(order)).to be false
    end

    it 'returns false if order has many shipments' do
      physical_line_item
      digital_line_item
      order.update_totals
      order.create_proposed_shipments

      expect(order.shipments.count).to eq(2)

      expect(helper.quick_checkout_enabled?(order)).to be false
    end

    it 'returns false if order does not require payment' do
      physical_line_item.update(price: 0)
      order.update_totals

      expect(order.total).to eq(0)
      expect(order.payment_required?).to be false

      expect(helper.quick_checkout_enabled?(order)).to be false
    end
  end
end
