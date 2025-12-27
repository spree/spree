# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Spree::InvitationEmailSubscriber do
  let(:store) { @default_store }
  let(:inviter) { create(:admin_user) }
  let(:invitee) { create(:admin_user) }
  let(:invitation) { create(:invitation, email: 'invited@example.com', inviter: inviter, resource: store, skip_email: true) }

  let(:subscriber) { described_class.new }

  def mock_event(invitation)
    double('Event', payload: { 'id' => invitation.id })
  end

  describe 'invitation.created event' do
    it 'sends invitation email' do
      expect(Spree::InvitationMailer).to receive(:invitation_email).with(kind_of(Spree::Invitation)).and_return(double(deliver_later: true))

      subscriber.send(:send_invitation_email, mock_event(invitation))
    end

    context 'when invitation not found' do
      it 'does not raise an error' do
        invitation_id = invitation.id
        invitation.destroy

        expect { subscriber.send(:send_invitation_email, mock_event(OpenStruct.new(id: invitation_id))) }.not_to raise_error
      end
    end
  end

  describe 'invitation.accepted event' do
    before do
      invitation.update!(invitee: invitee)
    end

    it 'sends acceptance notification email' do
      expect(Spree::InvitationMailer).to receive(:invitation_accepted).with(kind_of(Spree::Invitation)).and_return(double(deliver_later: true))

      subscriber.send(:send_acceptance_notification, mock_event(invitation))
    end

    context 'when invitation not found' do
      it 'does not raise an error' do
        invitation_id = invitation.id
        invitation.destroy

        expect { subscriber.send(:send_acceptance_notification, mock_event(OpenStruct.new(id: invitation_id))) }.not_to raise_error
      end
    end
  end

  describe 'invitation.resent event' do
    it 'resends invitation email' do
      expect(Spree::InvitationMailer).to receive(:invitation_email).with(kind_of(Spree::Invitation)).and_return(double(deliver_later: true))

      subscriber.send(:resend_invitation_email, mock_event(invitation))
    end

    context 'when invitation is expired' do
      before do
        invitation.update_column(:expires_at, 1.day.ago)
      end

      it 'does not send invitation email' do
        expect(Spree::InvitationMailer).not_to receive(:invitation_email)

        subscriber.send(:resend_invitation_email, mock_event(invitation))
      end
    end

    context 'when invitation is accepted' do
      before do
        invitation.update!(invitee: invitee)
        invitation.update_column(:status, 'accepted')
      end

      it 'does not send invitation email' do
        expect(Spree::InvitationMailer).not_to receive(:invitation_email)

        subscriber.send(:resend_invitation_email, mock_event(invitation))
      end
    end

    context 'when invitation is deleted' do
      before do
        invitation.destroy
      end

      it 'does not send invitation email' do
        expect(Spree::InvitationMailer).not_to receive(:invitation_email)

        subscriber.send(:resend_invitation_email, mock_event(invitation))
      end
    end

    context 'when invitation not found' do
      it 'does not raise an error' do
        invitation_id = invitation.id
        invitation.destroy!

        expect { subscriber.send(:resend_invitation_email, mock_event(OpenStruct.new(id: invitation_id))) }.not_to raise_error
      end
    end
  end
end
