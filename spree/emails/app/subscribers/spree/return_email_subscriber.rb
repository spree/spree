# frozen_string_literal: true

module Spree
  class ReturnEmailSubscriber < Spree::Subscriber
    include Spree::Emails::PostSaleDelivery

    subscribes_to 'return.requested', 'return.approved', 'return.refunded'

    on 'return.requested', :send_requested_email
    on 'return.approved', :send_approved_email
    on 'return.refunded', :send_refunded_email

    private

    def send_requested_email(event)
      deliver(Spree::Return, event) { |return_record| ReturnMailer.requested_email(return_record.id) }
    end

    def send_approved_email(event)
      deliver(Spree::Return, event) { |return_record| ReturnMailer.approved_email(return_record.id) }
    end

    def send_refunded_email(event)
      deliver(Spree::Return, event) do |return_record|
        # A return owed nothing closes without a refund, so there is none to announce.
        ReturnMailer.refunded_email(return_record.id) unless return_record.refunded_total.zero?
      end
    end
  end
end
