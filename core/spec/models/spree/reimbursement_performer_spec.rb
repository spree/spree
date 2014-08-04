require 'spec_helper'

describe Spree::ReimbursementPerformer do

  let(:reimbursement) { create(:reimbursement, return_items_count: 1) }
  let(:payment) { reimbursement.order.payments.first }

  let!(:default_refund_reason) { Spree::RefundReason.find_or_create_by!(name: Spree::RefundReason::RETURN_PROCESSING_REASON, mutable: false) }

  before do
    reimbursement.update!(total: reimbursement.calculated_total)
  end

  describe '.simulate' do
    subject { Spree::ReimbursementPerformer.simulate(reimbursement) }

    it 'returns an array of readonly refunds' do
      expect(subject).to be_an Array
      expect(subject.map(&:class)).to eq [Spree::Refund]
      expect(subject.map(&:readonly?)).to be_true
    end

    context 'when no credit is allowed on the payment' do
      before do
        Spree::Payment.any_instance.should_receive(:credit_allowed).and_return 0
      end

      it 'returns an empty array' do
        expect(subject).to eq []
      end
    end
  end

  describe '.perform' do
    subject { Spree::ReimbursementPerformer.perform(reimbursement) }

    it 'returns an array refunds' do
      expect(subject).to be_an Array
      expect(subject.map(&:class)).to eq [Spree::Refund]
    end

    it 'performs the refund' do
      expect {
        subject
      }.to change { payment.refunds.count }.by(1)
      expect(payment.refunds.sum(:amount)).to eq reimbursement.return_items.to_a.sum(&:total)
    end

    context 'when no credit is allowed on the payment' do
      before do
        Spree::Payment.any_instance.should_receive(:credit_allowed).and_return 0
      end

      it 'returns an empty array' do
        expect(subject).to eq []
      end

      it 'performs the refund' do
        expect {
          subject
        }.to_not change { payment.refunds.count }
      end
    end
  end

end
