# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::RefundSerializer do
  let(:payment) { create(:payment, state: 'completed', amount: 100) }
  let(:refund) { create(:refund, payment: payment, amount: 10) }

  subject { described_class.serialize(refund) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(refund.id)
    end

    it 'includes amount' do
      expect(subject[:amount]).to be_present
    end

    it 'includes transaction_id' do
      expect(subject).to have_key(:transaction_id)
    end

    it 'includes foreign keys' do
      expect(subject[:payment_id]).to eq(refund.payment_id)
      expect(subject).to have_key(:refund_reason_id)
      expect(subject).to have_key(:reimbursement_id)
      expect(subject).to have_key(:refunder_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
