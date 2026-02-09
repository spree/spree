require 'spec_helper'

RSpec.describe Spree::CouponCode, type: :model do
  let!(:promotion) { create(:promotion, multi_codes: true, number_of_codes: 1) }
  let(:coupon_code) { create(:coupon_code, promotion: promotion) }

  describe 'validations' do
    describe 'code' do
      it 'validates presence' do
        coupon_code.code = nil
        expect(coupon_code).not_to be_valid
      end

      it 'validates uniqueness' do
        other_coupon_code = promotion.coupon_codes.last

        coupon_code.code = other_coupon_code.code
        expect(coupon_code).not_to be_valid
        expect(coupon_code.errors.full_messages).to include('Code has already been taken')

        other_coupon_code.destroy
        expect(coupon_code).to be_valid
      end
    end
  end
end
