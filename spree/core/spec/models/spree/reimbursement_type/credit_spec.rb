require 'spec_helper'

module Spree
  describe ReimbursementType::Credit, type: :model do
    subject { Spree::ReimbursementType::Credit.reimburse(reimbursement, [return_item], simulate) }

    let(:reimbursement)           { create(:reimbursement, return_items_count: 1) }
    let(:return_item)             { reimbursement.return_items.first }
    let(:payment)                 { reimbursement.order.payments.first }
    let(:simulate)                { false }
    let!(:default_refund_reason)  { Spree::RefundReason.find_or_create_by!(name: Spree::RefundReason::RETURN_PROCESSING_REASON, mutable: false) }
    let(:creditable)              { DummyCreditable.new(amount: 99.99) }

    class DummyCreditable < Spree::Base
      attr_accessor :amount
      self.table_name = 'spree_payments' # Your creditable class should not use this table
    end

    before do
      reimbursement.update!(total: reimbursement.calculated_total)
      allow(Spree::StoreCredit).to receive(:new).and_return(creditable)
    end

    describe '.reimburse' do
      context 'simulate is true' do
        let(:simulate) { true }

        it 'creates one readonly lump credit for all outstanding balance payable to the customer' do
          expect(subject.map(&:class)).to eq [Spree::Reimbursement::Credit]
          expect(subject.map(&:readonly?)).to eq [true]
          expect(subject.sum(&:amount)).to eq reimbursement.return_items.to_a.sum(&:total)
        end

        it 'does not save to the database' do
          expect { subject }.not_to change { Spree::Reimbursement::Credit.count }
        end
      end

      context 'simulate is false' do
        let(:simulate) { false }

        before do
          expect(creditable).to receive(:save).and_return(true)
        end

        it 'creates one lump credit for all outstanding balance payable to the customer' do
          expect { subject }.to change { Spree::Reimbursement::Credit.count }.by(1)
          expect(subject.sum(&:amount)).to eq reimbursement.return_items.to_a.sum(&:total)
        end
      end
    end
  end
end
