require 'spec_helper'

# A promotion is redeemed by a customer, once, at a checkout. That a basket
# happened to span several sellers — and so became several orders — must not
# spend a limited promotion two or three times over.
RSpec.describe Spree::Promotion, 'usage counted across a split checkout' do
  let(:store) { @default_store }
  let(:promotion) { create(:promotion, :with_order_adjustment, store: store, usage_limit: 2) }
  let(:action) { promotion.actions.first }

  # One checkout that produced `orders_count` orders, each carrying its own
  # discount row — which is what the split leaves behind.
  def redeem(orders_count)
    group = orders_count > 1 ? create(:order_group, store: store) : nil

    Array.new(orders_count) do
      order = create(:order, store: store, order_group: group, total: 10)
      line_item = create(:line_item, order: order)
      Spree::Discount.create!(
        order: order, line_item: line_item, promotion: promotion, promotion_action: action,
        kind: 'promotion', amount: -1, label: promotion.name
      )
      order
    end
  end

  describe '#credits_count' do
    it 'counts one checkout once, however many sellers it reached' do
      redeem(3)

      expect(promotion.credits_count).to eq(1)
    end

    it 'counts separate checkouts separately' do
      redeem(2)
      redeem(1)

      expect(promotion.credits_count).to eq(2)
    end
  end

  describe '#usage_limit_exceeded?' do
    it 'does not exhaust a two-use promotion on one split checkout' do
      redeem(3)
      next_order = create(:order, store: store, total: 10)

      expect(promotion.usage_limit_exceeded?(next_order)).to be(false)
    end

    it 'still stops at the limit across distinct checkouts' do
      redeem(2)
      redeem(1)
      next_order = create(:order, store: store, total: 10)

      expect(promotion.usage_limit_exceeded?(next_order)).to be(true)
    end

    # An order asking whether it may still use a promotion must not be told no
    # on the strength of its own siblings' rows.
    it 'discounts the asking order’s whole group from the tally' do
      orders = redeem(2)

      expect(promotion.adjusted_credits_count(orders.first)).to eq(0)
    end
  end

  describe '#used_by?' do
    let(:customer) { create(:user) }

    def redeem_for(customer, orders_count)
      redeem(orders_count).each do |order|
        order.update_columns(customer_id: customer.id, status: 'placed', completed_at: Time.current)
      end
    end

    it 'does not count a customer’s own split checkout against them' do
      orders = redeem_for(customer, 3)

      expect(promotion.used_by?(customer, [orders.first])).to be(false)
    end

    it 'still reports a promotion used on an earlier checkout' do
      redeem_for(customer, 2)
      later = redeem(1).first

      expect(promotion.used_by?(customer, [later])).to be(true)
    end
  end
end
