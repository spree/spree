# frozen_string_literal: true

module Spree
  class InvitationEmailSubscriber < Spree::Subscriber
    subscribes_to 'invitation.create', 'invitation.accept', 'invitation.resend'

    on 'invitation.create', :send_invitation_email
    on 'invitation.accept', :send_acceptance_notification
    on 'invitation.resend', :resend_invitation_email

    private

    def send_invitation_email(event)
      invitation = find_invitation(event)
      return unless invitation

      InvitationMailer.invitation_email(invitation).deliver_later
    end

    def send_acceptance_notification(event)
      invitation = find_invitation(event)
      return unless invitation

      InvitationMailer.invitation_accepted(invitation).deliver_later
    end

    def resend_invitation_email(event)
      invitation = find_invitation(event)
      return unless invitation
      return if invitation.expired? || invitation.deleted? || invitation.accepted?

      InvitationMailer.invitation_email(invitation).deliver_later
    end

    def find_invitation(event)
      invitation_id = event.payload['id']
      Spree::Invitation.find_by(id: invitation_id)
    end
  end
end
