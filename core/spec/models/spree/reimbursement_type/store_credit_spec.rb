require 'spec_helper'

module Spree
  describe ReimbursementType::StoreCredit do
    subject do
      Spree::ReimbursementType::StoreCredit.reimburse(reimbursement, [return_item, return_item2],
                                                      simulate)
    end

    let(:reimbursement) { create(:reimbursement, return_items_count: 2) }
    let(:return_item) { reimbursement.return_items.first }
    let(:return_item2) { reimbursement.return_items.last }
    let(:payment) { reimbursement.order.payments.first }
    let(:simulate) { false }
    let!(:default_refund_reason) do
      Spree::RefundReason.find_or_create_by!(name: Spree::RefundReason::RETURN_PROCESSING_REASON,
                                             mutable: false)
    end

    let!(:primary_credit_type) { create(:primary_credit_type) }
    let!(:created_by_user) { create(:user, email: Spree::StoreCredit::DEFAULT_CREATED_BY_EMAIL) }
    let!(:default_reimbursement_category) { create(:store_credit_category) }

    before { reimbursement.update!(total: reimbursement.calculated_total) }

    describe '.reimburse' do
      context 'simulate is true' do
        let(:simulate) { true }

        context 'for store credits that the customer used' do
          before do
            allow(reimbursement).to receive_message_chain('order.payments.completed.store_credits').and_return([payment])
          end

          it 'creates readonly refunds for all store credit payments' do
            expect(subject.map(&:class)).to eq [Spree::Refund]
            expect(subject.map(&:readonly?)).to eq [true]
          end

          it 'does not save to the database' do
            expect { subject }.not_to change { payment.refunds.count }
          end
        end

        context 'for return items that were not paid for with store credit' do
          context 'creates one readonly lump credit for all outstanding balance payable to the customer' do
            it 'creates a credit that is read only' do
              expect(subject.map(&:class)).to eq [Spree::Reimbursement::Credit]
              expect(subject.map(&:readonly?)).to eq [true]
            end

            it 'creates a credit which amounts to the sum of the return items rounded down' do
              allow(return_item).to receive(:total).and_return(10.0076)
              allow(return_item2).to receive(:total).and_return(10.0023)
              expect(subject.sum(&:amount)).to eq 20.0
            end
          end

          it 'does not save to the database' do
            expect { subject }.not_to change { Spree::Reimbursement::Credit.count }
          end
        end
      end

      context 'simulate is false' do
        let(:simulate) { false }

        context 'for store credits that the customer used' do
          before do
            allow(reimbursement).to receive_message_chain('order.payments.completed.store_credits').and_return([payment])
          end

          it 'performs refunds for all store credit payments' do
            expect { subject }.to change { payment.refunds.count }.by(1)
            expect(payment.refunds.sum(:amount)).to eq reimbursement.return_items.to_a.sum(&:total)
          end
        end

        context 'for return items that were not paid for with store credit' do
          before do
            allow(Spree::ReimbursementType::StoreCredit).to receive(:store_credit_payments).and_return([])
          end

          it 'creates one lump credit for all outstanding balance payable to the customer' do
            expect { subject }.to change { Spree::Reimbursement::Credit.count }.by(1)
            expect(subject.sum(&:amount)).to eq reimbursement.return_items.to_a.sum(&:total)
          end

          it "creates a store credit with the same currency as the reimbursement's order" do
            expect { subject }.to change { Spree::StoreCredit.count }.by(1)
            expect(Spree::StoreCredit.last.currency).to eq reimbursement.order.currency
          end
        end
      end
    end
  end
end
