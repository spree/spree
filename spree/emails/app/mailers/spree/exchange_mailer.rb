module Spree
  class ExchangeMailer < BaseMailer
    include Spree::Emails::OrderPageUrl

    # Acknowledges an exchange request the moment it is opened — the same
    # durable confirmation a return gets (Consumer Rights Directive Art. 11(3)).
    def requested_email(exchange)
      deliver_exchange_email(exchange)
    end

    # Tells the customer where to send the goods going back.
    def approved_email(exchange)
      deliver_exchange_email(exchange)
    end

    private

    def deliver_exchange_email(exchange)
      @exchange = exchange.respond_to?(:id) ? exchange : Spree::Exchange.find(exchange)
      deliver_post_sale_email(@exchange, :exchange, Spree::Emails::ExchangeSerializer)
    end
  end
end
