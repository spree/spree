require 'spec_helper'

RSpec.describe Spree::Invitation, type: :model do
  let!(:store) { create(:store, default: true) }
  let(:invitation) { create(:invitation) }

  before do
    clear_enqueued_jobs
  end

  describe 'Validations' do
    let(:invitation) { build(:invitation) }

    context 'when invitee is the same as inviter' do
      it 'is invalid' do
        invitation.invitee = invitation.inviter
        expect(invitation).not_to be_valid
        expect(invitation.errors[:invitee]).to include('cannot be the same as the inviter')
      end
    end

    context 'when invitee already exists in the store' do
      it 'is invalid' do
        create(:admin_user, email: 'existing@example.com')
        invitation.email = 'existing@example.com'

        expect(invitation).not_to be_valid
        expect(invitation.errors[:email]).to include('already exists')
      end
    end
  end

  describe 'Callbacks' do
    it 'sets defaults on initialization' do
      invitation = build(:invitation)
      expect(invitation.expires_at).to be_present
    end

    # Resolved at validation, not on initialize: the caller's own resource is
    # not assigned yet when the record is instantiated.
    it 'defaults the resource before validation' do
      invitation = build(:invitation)
      invitation.valid?

      expect(invitation.resource).to eq(Spree::Store.current)
    end

    # Defaulting to the admin role let anyone allowed to invite staff hand out
    # admin by leaving the role out.
    it 'never defaults the role' do
      invitation = build(:invitation, role: nil)

      expect(invitation).not_to be_valid
      expect(invitation.role).to be_nil
      expect(invitation.errors[:role]).to be_present
    end

    it 'follows an explicitly assigned resource' do
      other_store = create(:store)
      invitation = build(:invitation, resource: other_store)
      invitation.valid?

      expect(invitation.role).to eq(Spree::Role.default_admin_role(other_store))
    end

    it 'sets invitee from email before validation' do
      create(:admin_user, :without_admin_role, email: 'test@example.com')

      invitation = build(:invitation, email: 'test@example.com')
      expect(invitation.invitee).to be_nil
      invitation.save
      expect(invitation.invitee).to be_present
    end
  end

  describe 'State Machine' do
    context 'when accepting an invitation' do
      it 'creates a resource user' do
        invitation.invitee = create(:admin_user, :without_admin_role)
        expect { Spree.invitation_accept_workflow.call(invitation: invitation) }.to change(invitation, :role_user).from(nil).to(Spree::RoleUser)
        expect(invitation.role_user.user).to eq(invitation.invitee)
        expect(invitation.role_user.resource).to eq(invitation.resource)
        expect(invitation.role_user.invitation).to eq(invitation)
        expect(invitation.role_user.role).to eq(invitation.role)
      end
    end
  end

  describe '#expired?' do
    it 'returns true when expires_at is in the past' do
      invitation.expires_at = 1.day.ago
      expect(invitation.expired?).to be true
    end

    it 'returns false when expires_at is in the future' do
      invitation.expires_at = 1.day.from_now
      expect(invitation.expired?).to be false
    end

    it 'returns false when the invitation has no expiry' do
      invitation.expires_at = nil
      expect(invitation.expired?).to be false
    end
  end

  describe '#resend!' do
    it 'publishes invitation.resent event if invitation is pending and not expired', events: true do
      expect(invitation).to receive(:publish_event).with('invitation.resent')
      invitation.resend!
    end

    it 'does not publish event if invitation is expired', events: true do
      allow(invitation).to receive(:expired?).and_return(true)
      expect(invitation).not_to receive(:publish_event)
      invitation.resend!
    end

    it 'does not publish event if invitation is accepted', events: true do
      invitation.invitee = create(:admin_user, :without_admin_role)
      expect(invitation).to receive(:publish_event).with('invitation.accepted')
      Spree.invitation_accept_workflow.call(invitation: invitation)

      expect(invitation).not_to receive(:publish_event)
      invitation.resend!
    end

    # A link that leaked with the earlier email must stop working.
    it 'rotates the token' do
      expect { invitation.resend! }.to change { invitation.reload.token }
    end

    it 'keeps the token of an expired invitation' do
      invitation.update_column(:expires_at, 1.day.ago)

      expect { invitation.resend! }.not_to change { invitation.reload.token }
    end

    # The new email carries a link good for the full window, not whatever was
    # left of the first one.
    it 'starts the expiry window again from the resend' do
      invitation.update_column(:expires_at, 1.hour.from_now)

      freeze_time do
        invitation.resend!

        expect(invitation.reload.expires_at).to eq(2.weeks.from_now)
      end
    end

    it 'leaves the expiry of an expired invitation alone and says it refused' do
      invitation.update_column(:expires_at, 1.hour.ago)

      result = nil
      expect { result = invitation.resend! }.not_to change { invitation.reload.expires_at }
      expect(result).to be(false)
    end

    it 'says it sent the invitation again' do
      expect(invitation.resend!).to be(true)
    end

    it 'gives an invitation with no expiry a fresh window instead of raising' do
      invitation.update_column(:expires_at, nil)

      freeze_time do
        expect(invitation.resend!).to be(true)
        expect(invitation.reload.expires_at).to eq(2.weeks.from_now)
      end
    end

    it 'never moves the expiry past MAX_LIFETIME after the invitation was created' do
      invitation.update_columns(created_at: 20.days.ago, expires_at: 1.hour.from_now)

      freeze_time do
        expect(invitation.resend!).to be(true)
        expect(invitation.reload.expires_at).to eq(invitation.created_at + described_class::MAX_LIFETIME)
      end
    end

    it 'refuses an invitation older than MAX_LIFETIME as expired' do
      invitation.update_columns(created_at: 31.days.ago, expires_at: 1.hour.from_now)

      expect { expect(invitation.resend!).to be(false) }.not_to change { invitation.reload.token }
      expect(invitation.resend_refusal).to eq(:expired)
    end

    it 'refuses an invalid record without raising and keeps its saved expiry and token', events: true do
      invitation.update_column(:email, 'not-an-email')
      saved = invitation.reload.attributes.slice('expires_at', 'token')
      expect(invitation).not_to receive(:publish_event)

      expect(invitation.resend!).to be(false)
      expect(invitation.resend_refusal).to be_nil
      expect(invitation.errors[:email]).to be_present
      expect(invitation.attributes.slice('expires_at', 'token')).to eq(saved)
      expect(invitation.reload.attributes.slice('expires_at', 'token')).to eq(saved)
    end

    # Another request accepted or revoked the invitation after this one loaded it.
    context 'when the invitation changed after it was loaded' do
      before { invitation }

      it 'refuses one accepted in the meantime', events: true do
        described_class.where(id: invitation.id).update_all(status: 'accepted', accepted_at: Time.current)
        expect(invitation).not_to receive(:publish_event)

        expect(invitation.resend!).to be(false)
        expect(invitation.resend_refusal).to eq(:already_accepted)
      end

      it 'refuses one revoked in the meantime', events: true do
        described_class.where(id: invitation.id).update_all(deleted_at: Time.current)
        expect(invitation).not_to receive(:publish_event)

        expect(invitation.resend!).to be(false)
        expect(invitation.resend_refusal).to eq(:revoked)
      end
    end
  end

  describe '#acceptance_url' do
    it 'carries the invitation and its token' do
      expect(invitation.acceptance_url).to include("/accept-invitation/#{invitation.prefixed_id}?token=#{invitation.token}")
    end
  end

  describe '#invitee_account' do
    let!(:account) { create(:admin_user, email: 'pat@example.com') }

    it 'finds the account for a differently cased address' do
      invitation = build(:invitation, email: 'Pat@Example.com')

      expect(invitation.invitee_account).to eq(account)
    end

    it 'is nil when no account holds the address' do
      expect(build(:invitation, email: 'nobody@example.com').invitee_account).to be_nil
    end

    # An app may encrypt the column, deterministically so it can still be
    # looked up. SQL then only ever sees ciphertext.
    context 'when the app encrypts email' do
      let(:account_class) do
        stub_const('EncryptedEmailAdmin', Class.new(Spree.admin_user_class) do
          self.table_name = Spree.admin_user_class.table_name
          encrypts :email, deterministic: true, downcase: true
        end)
      end
      let!(:account) { account_class.find(create(:admin_user).id).tap { |user| user.update_columns(email: 'pat@example.com') } }

      before { allow(Spree).to receive(:admin_user_class).and_return(account_class) }

      it 'finds the account, whatever the case' do
        stored = account_class.connection.select_value(account_class.unscoped.where(id: account.id).select(:email).to_sql)
        expect(stored).not_to include('example.com')

        expect(build(:invitation, email: 'Pat@Example.com').invitee_account).to eq(account)
      end
    end
  end
end
