require 'spec_helper'

RSpec.describe Spree::PaymentCaptureEvent, type: :model do
  let(:payment) { create(:payment, status: 'completed') }
  let!(:completed) { create(:payment_capture_event, payment: payment) }
  let!(:unset) { create(:payment_capture_event, payment: payment).tap { |event| event.update_column(:status, nil) } }
  let!(:requested) { create(:payment_capture_event, :requested, payment: payment) }
  let!(:failed) { create(:payment_capture_event, :failed, payment: payment) }

  describe '#status' do
    it 'reads an empty status as completed' do
      expect(unset.reload.status).to eq('completed')
      expect(unset).to be_completed
    end

    it 'saves a row with an empty status' do
      expect(unset.reload.update(amount: 5)).to be(true)
    end
  end

  describe '.completed_or_unset' do
    it 'returns completed and empty rows' do
      expect(described_class.completed_or_unset).to contain_exactly(completed, unset)
    end
  end

  describe '.not_failed' do
    it 'returns every row that has not failed' do
      expect(described_class.not_failed).to contain_exactly(completed, unset, requested)
    end
  end
end
