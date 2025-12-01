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

    context 'when invitation is accepted after expiration' do
      it 'is invalid' do
        invitation.expires_at = 1.day.ago
        expect(invitation.accept).to be_falsey

        expect(invitation.accepted_at).not_to be_present
        expect(invitation.status).to eq('pending')
        expect(invitation.errors[:base]).to include('Invitation expired')
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
      expect(invitation.resource).to eq(Spree::Store.current)
      expect(invitation.role).to eq(Spree::Role.default_admin_role)
    end

    it 'publishes invitation.create event after create' do
      Spree::Events.activate!

      received_event = nil
      subscriber = Spree::Events.subscribe('invitation.create') do |event|
        received_event = event
      end

      invitation = build(:invitation)
      invitation.save

      expect(received_event).to be_present
      expect(received_event.payload['id']).to eq(invitation.id)

      Spree::Events.unsubscribe('invitation.create', subscriber)
      Spree::Events.reset!
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
    it 'has initial state of pending' do
      expect(invitation.status).to eq('pending')
    end

    context 'when accepting an invitation' do
      it 'changes status to accepted' do
        invitation.invitee = create(:admin_user, :without_admin_role)
        invitation.accept
        expect(invitation.status).to eq('accepted')
      end

      it 'sets accepted_at timestamp' do
        expect(invitation.accepted_at).to be_nil
        invitation.invitee = create(:admin_user, :without_admin_role)
        invitation.accept
        expect(invitation.accepted_at).to be_present
      end

      it 'publishes invitation.accept event' do
        invitation.invitee = create(:admin_user, :without_admin_role)

        Spree::Events.activate!

        received_event = nil
        subscriber = Spree::Events.subscribe('invitation.accept') do |event|
          received_event = event
        end

        invitation.accept

        expect(received_event).to be_present
        expect(received_event.payload['id']).to eq(invitation.id)

        Spree::Events.unsubscribe('invitation.accept', subscriber)
        Spree::Events.reset!
      end

      it 'creates a resource user' do
        invitation.invitee = create(:admin_user, :without_admin_role)
        expect { invitation.accept }.to change(invitation, :role_user).from(nil).to(Spree::RoleUser)
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
  end

  describe '#resend!' do
    it 'publishes invitation.resend event if invitation is pending and not expired' do
      Spree::Events.activate!

      received_event = nil
      subscriber = Spree::Events.subscribe('invitation.resend') do |event|
        received_event = event
      end

      invitation.resend!

      expect(received_event).to be_present
      expect(received_event.payload['id']).to eq(invitation.id)

      Spree::Events.unsubscribe('invitation.resend', subscriber)
      Spree::Events.reset!
    end

    it 'does not publish event if invitation is expired' do
      Spree::Events.activate!

      received_event = nil
      subscriber = Spree::Events.subscribe('invitation.resend') do |event|
        received_event = event
      end

      allow(invitation).to receive(:expired?).and_return(true)
      invitation.resend!

      expect(received_event).to be_nil

      Spree::Events.unsubscribe('invitation.resend', subscriber)
      Spree::Events.reset!
    end

    it 'does not publish event if invitation is accepted' do
      Spree::Events.activate!

      received_event = nil
      subscriber = Spree::Events.subscribe('invitation.resend') do |event|
        received_event = event
      end

      invitation.invitee = create(:admin_user, spree_roles: [])
      invitation.accept
      invitation.resend!

      expect(received_event).to be_nil

      Spree::Events.unsubscribe('invitation.resend', subscriber)
      Spree::Events.reset!
    end
  end

end
