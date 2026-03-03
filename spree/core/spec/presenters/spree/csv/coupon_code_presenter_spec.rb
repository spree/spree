require 'spec_helper'

RSpec.describe Spree::CSV::CouponCodePresenter, type: :model do
  let(:promotion) { create(:promotion, name: 'Summer Sale') }
  let(:order) { create(:order, number: 'R123456') }
  let(:coupon_code) do
    create(:coupon_code,
           code: 'summer20',
           state: :used,
           promotion: promotion,
           order: order)
  end
  let(:presenter) { described_class.new(coupon_code) }

  describe '#call' do
    subject { presenter.call }

    it 'returns the correct CSV data' do
      expect(subject).to be_an(Array)
      expect(subject[0]).to eq('SUMMER20')      # Code (uppercased)
      expect(subject[1]).to eq('used')           # State
      expect(subject[2]).to eq('Summer Sale')    # Promotion Name
      expect(subject[3]).to eq('R123456')        # Order Number
      expect(subject[4]).to be_present           # Created At
      expect(subject[5]).to be_present           # Updated At
    end

    context 'when coupon code is unused' do
      let(:coupon_code) { create(:coupon_code, state: :unused, promotion: promotion) }

      it 'returns nil for order number' do
        expect(subject[1]).to eq('unused')
        expect(subject[3]).to be_nil
      end
    end
  end

  describe 'HEADERS' do
    it 'has the correct headers' do
      expected_headers = [
        'Code',
        'State',
        'Promotion Name',
        'Order Number',
        'Created At',
        'Updated At'
      ]
      expect(described_class::HEADERS).to eq(expected_headers)
    end
  end
end
