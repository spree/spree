# frozen_string_literal: true

module Spree
  class GiftCardEmailSubscriber < Spree::Subscriber
    subscribes_to 'gift_card.issued'

    def handle(event)
      gift_card = Spree::GiftCard.find_by_prefix_id(event.payload['id'])
      return unless gift_card&.line_item
      return unless gift_card.store.prefers_send_consumer_transactional_emails?

      send_at = gift_card.line_item.gift_card_recipient&.send_at
      email = GiftCardMailer.issued_email(gift_card.id)
      send_at&.future? ? email.deliver_later(wait_until: send_at) : email.deliver_later
    end
  end
end
