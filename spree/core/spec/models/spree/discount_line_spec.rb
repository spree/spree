require 'spec_helper'

describe Spree::DiscountLine, type: :model do
  it_behaves_like 'an adjustment line'

  describe 'amount validation' do
    it 'is strictly negative — zero and positive amounts are invalid' do
      expect(build(:discount_line, amount: -0.01)).to be_valid
      expect(build(:discount_line, amount: 0)).not_to be_valid
      expect(build(:discount_line, amount: 5)).not_to be_valid
    end
  end

  describe '#promotion? / #manual?' do
    it 'derives from promotion_action presence' do
      manual = build(:discount_line)
      promo = build(:discount_line, :from_promotion)

      expect(manual).to be_manual
      expect(manual).not_to be_promotion
      expect(promo).to be_promotion
      expect(promo).not_to be_manual
    end
  end

  describe 'scopes' do
    let!(:manual_line) { create(:discount_line) }
    let!(:promo_line) { create(:discount_line, :from_promotion) }

    it 'partitions manual and promotion-backed lines' do
      expect(described_class.manual).to contain_exactly(manual_line)
      expect(described_class.from_promotions).to contain_exactly(promo_line)
    end

    it 'filters automatic promotions via the Promotion enum scope' do
      promo_line.promotion.update!(kind: :automatic, code: nil)

      expect(described_class.automatic).to contain_exactly(promo_line)
    end
  end

  describe 'prefixed id' do
    it 'uses the dl prefix' do
      expect(create(:discount_line).prefixed_id).to start_with('dl_')
    end
  end

  it 'resolves a soft-deleted promotion action on a completed order' do
    discount_line = create(:discount_line, :from_promotion)
    discount_line.order.update_columns(state: 'complete', completed_at: Time.current)
    discount_line.promotion_action.destroy!

    expect(discount_line.reload.promotion_action).to be_present
  end
end
