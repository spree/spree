# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::Events::ReimbursementSerializer do
  let(:reimbursement) { create(:reimbursement) }

  subject { described_class.serialize(reimbursement) }

  describe '#as_json' do
    it 'includes identity attributes' do
      expect(subject[:id]).to eq(reimbursement.prefixed_id)
      expect(subject[:number]).to eq(reimbursement.number)
    end

    it 'includes reimbursement_status' do
      expect(subject[:reimbursement_status]).to be_present
    end

    it 'includes total' do
      expect(subject).to have_key(:total)
    end

    it 'includes foreign keys' do
      expect(subject[:order_id]).to eq(reimbursement.order&.prefixed_id)
      expect(subject[:customer_return_id]).to eq(reimbursement.customer_return&.prefixed_id)
    end

    it 'includes timestamps' do
      expect(subject[:created_at]).to be_present
      expect(subject[:updated_at]).to be_present
    end
  end
end
