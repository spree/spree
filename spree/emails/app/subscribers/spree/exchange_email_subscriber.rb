# frozen_string_literal: true

module Spree
  class ExchangeEmailSubscriber < Spree::Subscriber
    include Spree::Emails::PostSaleDelivery

    subscribes_to 'exchange.requested', 'exchange.approved'

    on 'exchange.requested', :send_requested_email
    on 'exchange.approved', :send_approved_email

    private

    def send_requested_email(event)
      deliver(Spree::Exchange, event) { |exchange| ExchangeMailer.requested_email(exchange.id) }
    end

    def send_approved_email(event)
      deliver(Spree::Exchange, event) { |exchange| ExchangeMailer.approved_email(exchange.id) }
    end
  end
end
