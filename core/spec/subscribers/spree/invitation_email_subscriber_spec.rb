# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::InvitationEmailSubscriber do
  include ActiveJob::TestHelper

  let(:store) { @default_store }
  let(:inviter) { create(:admin_user) }
  let(:invitee) { create(:admin_user) }
  let(:invitation) { create(:invitation, email: 'invited@example.com', inviter: inviter, resource: store, skip_email: true) }

  def publish_event(event_name, invitation)
    perform_enqueued_jobs(only: Spree::Events::SubscriberJob) do
      Spree::Events.publish(
        event_name,
        { 'id' => invitation.id }
      )
    end
  end

  before do
    # Unregister first to avoid duplicate subscriptions from engine initialization
    described_class.unregister!
    described_class.register!
  end

  after do
    described_class.unregister!
  end

  describe 'invitation.create event' do
    it 'sends invitation email' do
      expect(Spree::InvitationMailer).to receive(:invitation_email).with(kind_of(Spree::Invitation)).and_return(double(deliver_later: true))

      publish_event('invitation.create', invitation)
    end

    context 'when invitation not found' do
      it 'does not raise an error' do
        invitation_id = invitation.id
        invitation.destroy

        expect { publish_event('invitation.create', OpenStruct.new(id: invitation_id)) }.not_to raise_error
      end
    end
  end

  describe 'invitation.accept event' do
    before do
      invitation.update!(invitee: invitee)
    end

    it 'sends acceptance notification email' do
      expect(Spree::InvitationMailer).to receive(:invitation_accepted).with(kind_of(Spree::Invitation)).and_return(double(deliver_later: true))

      publish_event('invitation.accept', invitation)
    end

    context 'when invitation not found' do
      it 'does not raise an error' do
        invitation_id = invitation.id
        invitation.destroy

        expect { publish_event('invitation.accept', OpenStruct.new(id: invitation_id)) }.not_to raise_error
      end
    end
  end

  describe 'invitation.resend event' do
    it 'resends invitation email' do
      expect(Spree::InvitationMailer).to receive(:invitation_email).with(kind_of(Spree::Invitation)).and_return(double(deliver_later: true))

      publish_event('invitation.resend', invitation)
    end

    context 'when invitation is expired' do
      before do
        invitation.update_column(:expires_at, 1.day.ago)
      end

      it 'does not send invitation email' do
        expect(Spree::InvitationMailer).not_to receive(:invitation_email)

        publish_event('invitation.resend', invitation)
      end
    end

    context 'when invitation is accepted' do
      before do
        invitation.update!(invitee: invitee)
        invitation.update_column(:status, 'accepted')
      end

      it 'does not send invitation email' do
        expect(Spree::InvitationMailer).not_to receive(:invitation_email)

        publish_event('invitation.resend', invitation)
      end
    end

    context 'when invitation is deleted' do
      before do
        invitation.destroy
      end

      it 'does not send invitation email' do
        expect(Spree::InvitationMailer).not_to receive(:invitation_email)

        publish_event('invitation.resend', invitation)
      end
    end

    context 'when invitation not found' do
      it 'does not raise an error' do
        invitation_id = invitation.id
        invitation.destroy!

        expect { publish_event('invitation.resend', OpenStruct.new(id: invitation_id)) }.not_to raise_error
      end
    end
  end
end
