require 'spec_helper'

describe Spree.admin_user_class, type: :model do
  let(:admin_user) { create(:admin_user) }

  it_behaves_like 'account lockout' do
    let(:lockable) { admin_user }
  end

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
  end

  describe 'deactivation' do
    it 'starts active' do
      expect(admin_user).not_to be_deactivated
    end

    it 'records when the account was switched off' do
      admin_user.deactivate!

      expect(admin_user.reload).to be_deactivated
      expect(admin_user.deactivated_at).to be_within(2.seconds).of(Time.current)
    end

    it 'ends every session the account holds, on every surface' do
      create(:refresh_token, :for_admin, user: admin_user)
      create(:refresh_token, user: admin_user, audience: 'seller_api')
      someone_else = create(:refresh_token, :for_admin)

      admin_user.deactivate!

      expect(Spree::RefreshToken.where(user: admin_user)).to be_empty
      expect(Spree::RefreshToken.exists?(someone_else.id)).to be(true)
    end

    it 'keeps the first deactivation time when called again' do
      admin_user.deactivate!
      first = admin_user.reload.deactivated_at

      travel(1.hour) { admin_user.deactivate! }

      expect(admin_user.reload.deactivated_at).to eq(first)
    end

    it 'ends the sessions of an account already marked deactivated' do
      admin_user.update_column(:deactivated_at, 1.day.ago)
      create(:refresh_token, :for_admin, user: admin_user)

      admin_user.deactivate!

      expect(Spree::RefreshToken.where(user: admin_user)).to be_empty
    end

    # Switching an account off must not depend on its other attributes
    # passing today's validations.
    it 'deactivates an account that no longer validates' do
      allow(admin_user).to receive(:valid?).and_return(false)

      admin_user.deactivate!

      expect(admin_user.reload).to be_deactivated
    end

    it 'lets a reactivated account in again' do
      admin_user.deactivate!
      admin_user.reactivate!

      expect(admin_user.reload).not_to be_deactivated
    end
  end

  describe '#status' do
    it 'is active by default' do
      expect(admin_user.status).to eq('active')
    end

    it 'is locked within the lockout window' do
      admin_user.update!(locked_at: Time.current)

      expect(admin_user.status).to eq('locked')
    end

    it 'is deactivated, even while locked' do
      admin_user.update!(locked_at: Time.current)
      admin_user.deactivate!

      expect(admin_user.status).to eq('deactivated')
    end
  end

  describe '#invited_by' do
    let(:store) { @default_store }
    let(:inviter) { create(:admin_user) }

    def invite(status:)
      create(:invitation, resource: store, inviter: inviter).tap do |invitation|
        invitation.update_columns(invitee_type: admin_user.class.polymorphic_name, invitee_id: admin_user.id, status: status)
      end
    end

    it 'is the inviter of the invitation the user accepted on the store' do
      invite(status: 'accepted')

      expect(admin_user.invited_by(store)).to eq(inviter)
    end

    it 'ignores an invitation the user has not accepted' do
      invite(status: 'pending')

      expect(admin_user.invited_by(store)).to be_nil
    end

    it 'is nil for a user added without an invitation' do
      expect(admin_user.invited_by(store)).to be_nil
    end
  end

  describe 'sessions' do
    let!(:older) { create(:refresh_token, :for_admin, user: admin_user, created_at: 2.days.ago) }
    let!(:newer) { create(:refresh_token, user: admin_user, audience: 'seller_api', created_at: 1.hour.ago) }
    let!(:expired) { create(:refresh_token, :for_admin, user: admin_user, created_at: 1.minute.ago, expires_at: 1.second.ago) }

    it 'lists the sessions that can still be refreshed, most recently used first' do
      expect(admin_user.active_sessions).to eq([newer, older])
    end

    it 'deletes its sessions with the account' do
      expect { admin_user.destroy }.to change { Spree::RefreshToken.where(user: admin_user).count }.from(3).to(0)
    end
  end

  describe '#last_active_at' do
    it 'is stamped when a session starts and when it refreshes' do
      token = Spree::RefreshToken.create_for(admin_user, audience: 'admin_api')
      expect(admin_user.reload.last_active_at).to be_within(1.second).of(token.created_at)

      travel 10.minutes do
        refreshed = token.rotate!
        expect(admin_user.reload.last_active_at).to be_within(1.second).of(refreshed.created_at)
      end
    end

    it 'outlives the session when the account signs out' do
      token = Spree::RefreshToken.create_for(admin_user, audience: 'admin_api')
      token.destroy

      expect(admin_user.reload.last_active_at).to be_present
    end

    it 'is nil for an account that never signed in' do
      expect(admin_user.last_active_at).to be_nil
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
      let!(:returns) { create_list(:return, 2, created_by: admin_user) }
      let!(:store_credits) { create_list(:store_credit, 2, created_by: admin_user) }
      let!(:exports) { create_list(:export, 2, user: admin_user) }

      it 'nullifies admin user resources' do
        expect { admin_user.destroy }.to change(Spree.admin_user_class, :count).by(-1).and change(Spree::Export, :count).by(-2)

        expect(cancelled_orders.all? { |order| order.reload.canceler_id.nil? }).to be_truthy
        expect(approved_orders.all? { |order| order.reload.approver_id.nil? }).to be_truthy
        expect(gift_card_batches.all? { |batch| batch.reload.created_by_id.nil? }).to be_truthy
        expect(gift_cards.all? { |gift_card| gift_card.reload.created_by_id.nil? }).to be_truthy
        expect(refunds.all? { |refund| refund.reload.refunder_id.nil? }).to be_truthy
        expect(returns.all? { |return_record| return_record.reload.created_by_id.nil? }).to be_truthy
        expect(store_credits.all? { |store_credit| store_credit.reload.created_by_id.nil? }).to be_truthy
      end

      # A type left behind would name a class no id points at.
      it 'clears both halves of a polymorphic actor' do
        admin_user.destroy

        expect(cancelled_orders.map { |order| order.reload.canceler_type }).to all(be_nil)
        expect(approved_orders.map { |order| order.reload.approver_type }).to all(be_nil)
        expect(refunds.map { |refund| refund.reload.refunder_type }).to all(be_nil)
        expect(returns.map { |record| record.reload.created_by_type }).to all(be_nil)
      end

      # Deleting a member of staff has to erase them from rows written before
      # the actor columns existed too — that window is exactly the upgrade
      # path, and it is personal data.
      it 'clears a row the backfill has not reached yet' do
        legacy = create(:order, canceler: admin_user, state: 'canceled')
        Spree::Order.where(id: legacy.id).update_all(canceler_type: nil)

        admin_user.destroy

        expect(legacy.reload.canceler_id).to be_nil
      end

      # Ids are per-table, so an API key can share this user's numeric id. A
      # bare foreign key would have swept its rows up with the user's.
      it 'leaves another kind of actor alone' do
        api_key = create(:api_key, :secret)
        key_order = create(:order, canceler: api_key, state: 'canceled')

        admin_user.destroy

        expect(key_order.reload.canceler).to eq(api_key)
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
          Spree.invitation_accept_workflow.call(invitation: invitation)
        end

        it 'does not remove other user\'s role' do
          expect { destroy_admin_user }.not_to change { other_user.role_users.count }
        end
      end
    end
  end
end
