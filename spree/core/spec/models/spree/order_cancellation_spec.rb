require 'spec_helper'

describe Spree::OrderCancellation, type: :model do
  let(:order) { create(:order) }

  describe 'validations' do
    it 'requires reason' do
      cancellation = described_class.new(order: order, reason: nil)
      expect(cancellation).not_to be_valid
      expect(cancellation.errors[:reason]).to include("can't be blank")
    end

    it 'rejects invalid reason values' do
      cancellation = described_class.new(order: order, reason: 'not_a_real_reason')
      expect(cancellation).not_to be_valid
      expect(cancellation.errors[:reason]).to include('is not included in the list')
    end

    it 'accepts each REASONS value' do
      Spree::OrderCancellation::REASONS.each do |reason|
        cancellation = described_class.new(order: order, reason: reason)
        cancellation.valid?
        expect(cancellation.errors[:reason]).to be_empty
      end
    end

    it 'rejects negative refund_amount' do
      cancellation = described_class.new(order: order, reason: 'other', refund_amount: -1)
      expect(cancellation).not_to be_valid
      expect(cancellation.errors[:refund_amount]).to include('must be greater than or equal to 0')
    end
  end

  describe 'prefixed id' do
    it 'has cncl_ prefix' do
      cancellation = described_class.create!(order: order, reason: 'other')
      expect(cancellation.prefixed_id).to start_with('cncl_')
    end
  end

  describe 'polymorphic canceled_by' do
    let(:admin) { create(:admin_user) }

    it 'records the canceler' do
      cancellation = described_class.create!(order: order, reason: 'staff', canceled_by: admin)
      expect(cancellation.canceled_by).to eq(admin)
    end

    it 'allows nil canceled_by' do
      cancellation = described_class.new(order: order, reason: 'other')
      expect(cancellation).to be_valid
    end
  end
end
