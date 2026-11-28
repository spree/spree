module Spree
  module Api
    module V3
      # The event shape for `gift_card.issued`: the card a paid order issued,
      # with who it is for, so a subscriber can deliver it.
      #
      # The code is masked here: this event exists to say who a card is for,
      # and a subscriber that delivers the card reads it through the Admin
      # API. The card's lifecycle `gift_card.created` event still carries the
      # code, as it does for cards staff issue; the delivery log redacts it
      # (Spree::WebhookPayloadRedaction).
      class GiftCardIssuedEventSerializer < GiftCardSerializer
        typelize line_item_id: [:string, nullable: true], order_id: [:string, nullable: true], recipient: { nullable: true }

        attribute :code, &:masked_code

        prefixed_id_attributes :line_item

        attribute :order_id do |gift_card|
          gift_card.line_item&.order&.prefixed_id
        end

        one :recipient, resource: proc { Spree.api.gift_card_recipient_serializer }, source: proc { line_item&.gift_card_recipient }
      end
    end
  end
end
