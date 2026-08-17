# frozen_string_literal: true

module Spree
  # Turns the seller lifecycle events into seller-facing mail.
  #
  # Nothing is sent from the workflows themselves: a transition publishes an
  # event, and mail is one listener among several (webhooks, analytics) rather
  # than a step the transition waits on.
  #
  # `seller.invited` is deliberately absent — inviting a seller creates an
  # Invitation, which already mails the invitee through InvitationEmailSubscriber.
  # A second email would be the same news to the same address.
  class SellerEmailSubscriber < Spree::Subscriber
    subscribes_to 'seller.approved', 'seller.suspended', 'seller.rejected'

    on 'seller.approved', :send_approved_email
    on 'seller.suspended', :send_suspended_email
    on 'seller.rejected', :send_rejected_email

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
      seller = find_seller(event)
      return unless seller
      return unless seller.store&.prefers_send_seller_transactional_emails?

      SellerMailer.public_send(mailer_method, seller.id).deliver_later
    end

    def find_seller(event)
      Spree::Seller.find_by_prefix_id(event.payload['id'])
    end
  end
end
