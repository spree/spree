require 'spec_helper'

describe Spree::Order do
  context 'when a discount zeroes the item total, but shipping raises the total above zero' do
    let!(:persisted_order) { create(:order) }
    let!(:line_item) { create(:line_item) }
    let!(:shipping_method) do
      sm = create(:shipping_method)
      sm.calculator.preferred_amount = 10
      sm.save
      sm
    end

    before do
      # Don't care about available payment methods in this test
      allow(persisted_order).to receive_messages(has_available_payment: false)
      persisted_order.line_items << line_item
      create(:discount, order: persisted_order, line_item: line_item, amount: -line_item.amount, label: 'Promotion', kind: 'manual')
      persisted_order.update_with_updater!
      persisted_order.state = 'delivery'
      persisted_order.save # To ensure new state_change event
    end

    it 'transitions from delivery to payment' do
      allow(persisted_order).to receive_messages(payment_required?: true)
      persisted_order.next!
      expect(persisted_order.state).to eq('payment')
    end
  end

  context 'when an order has an taxed shipment with tax included_in_price and apply free_shipping_promotion' do
    let!(:order) { create(:order) }
    let!(:line_item) { create(:line_item) }

    let!(:country) { create(:country) }
    let!(:zone) { create(:zone) }
    let!(:zone_member) { create(:zone_member, zone: zone, zoneable: country) }
    let(:address) { create(:address, country: country) }

    let!(:tax_category) { create(:tax_category) }
    let!(:tax_rate) {
      create(:tax_rate,
        amount: 0.2,
        included_in_price: true,
        tax_category: tax_category,
        zone: zone
      )
    }
    let!(:shipping_method) do
      sm = create(:shipping_method, tax_category: tax_category)
      sm.calculator.preferred_amount = 10
      sm.save
      sm
    end

    let!(:free_shipping_promotion) {
      create(:free_shipping_promotion, code: 'freeship', kind: :coupon_code)
    }

    before do
      order.line_items << line_item
      order.ship_address = address
      order.create_proposed_shipments
      order.send :ensure_available_shipping_rates
      order.set_shipments_cost
      order.create_shipment_tax_charge!
    end

    it 'removes the fulfillment tax lines' do
      order.coupon_code = free_shipping_promotion.code
      Spree::PromotionHandler::Coupon.new(order).apply
      order.apply_free_shipping_promotions

      expect(order.tax_lines.for_fulfillments).to be_blank
    end
  end
end
