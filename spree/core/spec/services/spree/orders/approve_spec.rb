require 'spec_helper'

module Spree
  describe Orders::Approve do
    subject { described_class }

    let(:order) { create(:completed_order_with_totals, considered_risky: true) }
    let(:user) { create(:admin_user) }

    let(:result) { subject.call(order: order, approver: user) }

    shared_examples 'approves order' do
      it { expect(result).to be_success }
      it { expect(result.value).to eq(order) }
      it { expect { result }.to change(order, :considered_risky).to(false) }
      it { expect { result }.to change { order.reload.approved_at }.from(nil) }
    end

    context 'with approver passed' do
      it_behaves_like 'approves order'

      it { expect { result }.to change(order, :approver).to(user) }
    end

    context 'without approver passed' do
      let(:user) { nil }

      it_behaves_like 'approves order'
    end

    describe 'OrderApproval record creation' do
      it 'creates an approval record with status approved' do
        expect { result }.to change(order.approvals, :count).by(1)
        approval = order.approvals.last
        expect(approval.status).to eq('approved')
        expect(approval.approver).to eq(user)
        expect(approval.decided_at).to be_present
      end

      context 'with level and note' do
        let(:result) do
          subject.call(order: order, approver: user, level: 'manager', note: 'Approved per phone call')
        end

        it 'records level and note on the approval' do
          result
          approval = order.approvals.last
          expect(approval.level).to eq('manager')
          expect(approval.note).to eq('Approved per phone call')
        end
      end
    end
  end
end
