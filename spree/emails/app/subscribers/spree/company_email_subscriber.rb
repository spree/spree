# frozen_string_literal: true

module Spree
  # Sends the company invitation mail when an invitation is created. Riding
  # the event rather than the write path lets a host app silence it (consumer
  # transactional emails off) and send its own instead.
  class CompanyEmailSubscriber < Spree::Subscriber
    subscribes_to 'company_invitation.created'

    def handle(event)
      invitation = Spree::CompanyInvitation.find_by_prefix_id(event.payload['id'])
      return unless invitation
      return unless invitation.pending?
      return unless invitation.store&.prefers_send_consumer_transactional_emails?

      CompanyMailer.invitation_email(invitation.id).deliver_later
    end
  end
end
