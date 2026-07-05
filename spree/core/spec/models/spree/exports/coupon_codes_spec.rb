require 'spec_helper'

RSpec.describe Spree::Exports::CouponCodes do
  let(:store) { @default_store }
  let(:user) { create(:admin_user) }
  let(:export) { build(:coupon_code_export, store: store, user: user, format: 'csv') }

  describe '#scope' do
    let!(:promotion) { create(:promotion, store: store, multi_codes: true, number_of_codes: 1, code_prefix: 'SAVE') }
    let!(:other_promotion) { create(:promotion, store: create(:store), multi_codes: true, number_of_codes: 1, code_prefix: 'NOPE') }

    # Regression: the scope must resolve via the single-store FK on Promotion,
    # not the removed has_many :stores join.
    it 'returns only coupon codes for promotions owned by the export store' do
      expect { export.records_to_export.to_a }.not_to raise_error
      expect(export.records_to_export.map(&:promotion_id).uniq).to eq([promotion.id])
    end
  end
end
