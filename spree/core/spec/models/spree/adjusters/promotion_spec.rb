require 'spec_helper'

describe Spree::Adjusters::Promotion, type: :model do
  let(:order) { create(:order) }
  let!(:line_item) { create(:line_item, order: order, price: 20, quantity: 1) }

  def adjust_all
    adjustables = order.line_items.reload.includes(:fees, discount_lines: [:promotion, :promotion_action]).to_a +
                  order.shipments.reload.includes(:fees, discount_lines: [:promotion, :promotion_action]).to_a
    described_class.adjust_all(order, adjustables)
  end

  def item_promo(amount)
    promotion = create(:promotion_with_item_adjustment, adjustment_rate: amount, kind: :automatic, code: nil, store: order.store)
    promotion.actions.first.perform(order: order, promotion: promotion)
    promotion
  end

  before { order.update_with_updater! }

  it 'declares the :discount type' do
    expect(described_class.type).to eq(:discount)
  end

  describe 'refreshing candidates' do
    it 'refreshes a stale amount from the action' do
      promotion = item_promo(5)
      line = line_item.discount_lines.first
      line.update_columns(amount: -1)

      adjust_all

      expect(line.reload.amount).to eq(-5)
      expect(promotion.discount_lines.count).to eq(1)
    end

    it 'destroys candidates that zero out' do
      item_promo(5)
      allow_any_instance_of(Spree::Promotion::Actions::CreateItemAdjustments).to receive(:compute_amount).and_return(0)

      adjust_all

      expect(line_item.discount_lines.reload).to be_empty
    end

    it 'destroys candidates whose promotion lost eligibility' do
      promotion = item_promo(5)
      promotion.update_columns(expires_at: 1.day.ago, starts_at: 2.days.ago)

      adjust_all

      expect(line_item.discount_lines.reload).to be_empty
    end

    it 'never creates rows' do
      create(:promotion_with_item_adjustment, adjustment_rate: 5, kind: :automatic, code: nil, store: order.store)

      expect { adjust_all }.not_to change(Spree::DiscountLine, :count)
    end

    it 'leaves manual discount lines untouched' do
      manual = create(:discount_line, line_item: line_item, amount: -3)

      adjust_all

      expect(manual.reload.amount).to eq(-3)
    end
  end

  describe 'best-promo competition per line item' do
    it 'keeps only the biggest discount' do
      item_promo(5)
      item_promo(10)

      adjust_all

      lines = line_item.discount_lines.reload
      expect(lines.count).to eq(1)
      expect(lines.first.amount).to eq(-10)
    end

    it 'breaks ties in favor of the newest candidate' do
      item_promo(5)
      newer = item_promo(5)

      adjust_all

      lines = line_item.discount_lines.reload
      expect(lines.count).to eq(1)
      expect(lines.first.promotion).to eq(newer)
    end
  end
end
