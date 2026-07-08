require 'spec_helper'

describe Spree.admin_user_class, type: :model do
  let(:admin_user) { create(:admin_user) }

  describe 'password reset tokens' do
    it 'round-trips through find_by_password_reset_token' do
      token = admin_user.generate_token_for(:password_reset)
      expect(described_class.find_by_password_reset_token(token)).to eq(admin_user)
    end

    it 'invalidates the token when the password changes' do
      token = admin_user.generate_token_for(:password_reset)
      admin_user.update!(password: 'new-secret-123', password_confirmation: 'new-secret-123')
      expect(described_class.find_by_password_reset_token(token)).to be_nil
    end

    # Regression: modern admin schemas have no password_salt column and Devise
    # defines no such method — the token payload must fall back to
    # encrypted_password instead of raising NameError. The test table
    # deliberately omits the legacy column so this spec exercises that path;
    # if password_salt ever responds again, the schema drifted back to the
    # legacy shape that masked the production 500.
    it 'generates tokens without a password_salt column' do
      expect(admin_user).not_to respond_to(:password_salt)
      expect(admin_user.generate_token_for(:password_reset)).to be_present
    end
  end

  describe '#send_devise_notification (Devise bridge)' do
    let(:mail) { double(deliver_later: true) }

    it 'routes reset password instructions through Spree::AdminUserMailer' do
      expect(Spree::AdminUserMailer).to receive(:password_reset_email).
        with(admin_user, 'devise-token', Spree::Store.default).and_return(mail)

      admin_user.send_devise_notification(:reset_password_instructions, 'devise-token', {})
    end

    it 'routes confirmation instructions through Spree::AdminUserMailer' do
      expect(Spree::AdminUserMailer).to receive(:confirmation_email).
        with(admin_user, 'devise-token', Spree::Store.default).and_return(mail)

      admin_user.send_devise_notification(:confirmation_instructions, 'devise-token', {})
    end
  end

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
