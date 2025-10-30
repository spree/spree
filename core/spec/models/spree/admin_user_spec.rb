require 'spec_helper'

describe Spree::LegacyUser, type: :model do
  let(:admin_user) { create(:admin_user) }

  describe '#can_be_deleted?' do
    subject { admin_user.can_be_deleted? }

    context 'when store has other admin users' do
      before do
        create(:admin_user)
      end

      it { is_expected.to be(true) }
    end

    context 'when store has no other admin users' do
      it { is_expected.to be(false) }
    end

    context 'when the user does not have admin role' do
      let(:admin_user) { create(:admin_user, without_admin_role: true) }

      it { is_expected.to be(true) }
    end
  end

  context 'Callbacks' do
    describe 'cleans up admin user resources' do
      let!(:other_admin_user) { create(:admin_user) }
      let!(:cancelled_orders) { create_list(:order, 2, canceler: admin_user, state: 'canceled') }
      let!(:approved_orders) { create_list(:order, 2, approver: admin_user) }
      let!(:gift_card_batches) { create_list(:gift_card_batch, 2, created_by: admin_user, amount: 100, prefix: 'TEST') }
      let!(:gift_cards) { create_list(:gift_card, 2, created_by: admin_user) }
      let!(:refunds) { create_list(:refund, 2, refunder: admin_user, amount: 1) }
      let!(:reimbursements) { create_list(:reimbursement, 2, performed_by: admin_user) }
      let!(:posts) { create_list(:post, 2, author: admin_user) }
      let!(:reports) { create_list(:report, 2, user: admin_user) }
      let!(:store_credits) { create_list(:store_credit, 2, created_by: admin_user) }
      let!(:exports) { create_list(:export, 2, user: admin_user) }

      it 'nullifies admin user resources' do
        expect { admin_user.destroy }.to change(Spree.admin_user_class, :count).by(-1).and change(Spree::Export, :count).by(-2).and change(Spree::Report, :count).by(-2)

        expect(cancelled_orders.all? { |order| order.reload.canceler_id.nil? }).to be_truthy
        expect(approved_orders.all? { |order| order.reload.approver_id.nil? }).to be_truthy
        expect(gift_card_batches.all? { |batch| batch.reload.created_by_id.nil? }).to be_truthy
        expect(gift_cards.all? { |gift_card| gift_card.reload.created_by_id.nil? }).to be_truthy
        expect(refunds.all? { |refund| refund.reload.refunder_id.nil? }).to be_truthy
        expect(reimbursements.all? { |reimbursement| reimbursement.reload.performed_by_id.nil? }).to be_truthy
        expect(posts.all? { |post| post.reload.author_id.nil? }).to be_truthy
        expect(store_credits.all? { |store_credit| store_credit.reload.created_by_id.nil? }).to be_truthy
      end
    end
  end

  describe '#destroy (regression tests)' do
    subject(:destroy_admin_user) { admin_user.destroy }

    context 'admin user invited other' do
      let(:other_user) { create(:admin_user, email: 'other_user@example.com', without_admin_role: true) }
      let(:invitation) { create(:invitation, email: other_user.email, inviter: admin_user) }

      context 'other users accept invitation' do
        before do
          invitation.accept!
        end

        it 'does not remove other user\'s role' do
          expect { destroy_admin_user }.not_to change { other_user.role_users.count }
        end
      end
    end
  end
end
