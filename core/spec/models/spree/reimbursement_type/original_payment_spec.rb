require 'spec_helper'

module Spree
  describe ReimbursementType::OriginalPayment, type: :model do
    subject { Spree::ReimbursementType::OriginalPayment.reimburse(reimbursement, [return_item], simulate) }

    let(:reimbursement)           { create(:reimbursement, return_items_count: 1) }
    let(:return_item)             { reimbursement.return_items.first }
    let(:payment)                 { reimbursement.order.payments.first }
    let(:simulate)                { false }
    let!(:default_refund_reason)  { Spree::RefundReason.find_or_create_by!(name: Spree::RefundReason::RETURN_PROCESSING_REASON, mutable: false) }

    before { reimbursement.update!(total: reimbursement.calculated_total) }

    describe '.reimburse' do
      context 'simulate is true' do
        let(:simulate) { true }

        it 'returns an array of readonly refunds' do
          expect(subject.map(&:class)).to eq [Spree::Refund]
          expect(subject.map(&:readonly?)).to eq [true]
        end
      end

      context 'simulate is false' do
        it 'performs the refund' do
          expect do
            subject
          end.to change { payment.refunds.count }.by(1)
          expect(payment.refunds.sum(:amount)).to eq reimbursement.return_items.to_a.sum(&:total)
        end
      end

      context 'when no credit is allowed on the payment' do
        before do
          expect_any_instance_of(Spree::Payment).to receive(:credit_allowed).and_return 0
        end

        it 'returns an empty array' do
          expect(subject).to eq []
        end
      end

      context 'when a payment is negative' do
        before do
          expect_any_instance_of(Spree::Payment).to receive(:amount).and_return(-100)
        end

        it 'returns an empty array' do
          expect(subject).to eq []
        end
      end
    end
  end
end
