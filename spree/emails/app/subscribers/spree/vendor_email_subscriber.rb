# frozen_string_literal: true

module Spree
  # Turns the vendor lifecycle events into seller-facing mail.
  #
  # Nothing is sent from the workflows themselves: a transition publishes an
  # event, and mail is one listener among several (webhooks, analytics) rather
  # than a step the transition waits on.
  #
  # `vendor.invited` is deliberately absent — inviting a vendor creates an
  # Invitation, which already mails the invitee through InvitationEmailSubscriber.
  # A second email would be the same news to the same address.
  class VendorEmailSubscriber < Spree::Subscriber
    subscribes_to 'vendor.approved', 'vendor.suspended', 'vendor.rejected'

    on 'vendor.approved', :send_approved_email
    on 'vendor.suspended', :send_suspended_email
    on 'vendor.rejected', :send_rejected_email

    private

    def send_approved_email(event)
      deliver(event, :approved_email)
    end

    def send_suspended_email(event)
      deliver(event, :suspended_email)
    end

    def send_rejected_email(event)
      deliver(event, :rejected_email)
    end

    def deliver(event, mailer_method)
      vendor = find_vendor(event)
      return unless vendor
      return unless vendor.store&.prefers_send_vendor_transactional_emails?

      VendorMailer.public_send(mailer_method, vendor.id).deliver_later
    end

    def find_vendor(event)
      Spree::Vendor.find_by_prefix_id(event.payload['id'])
    end
  end
end
