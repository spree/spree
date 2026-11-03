module Spree
  class GiftCardMailer < BaseMailer
    # Sends a bought gift card to the person it is for: the line's recipient,
    # or the buyer when they named no one. This email is the only place the
    # code travels; the buyer's own confirmation shows it masked.
    def issued_email(gift_card)
      @gift_card = gift_card.respond_to?(:id) ? gift_card : Spree::GiftCard.find_by(id: gift_card)
      @order = @gift_card&.line_item&.order
      return if @order.nil? || @gift_card.canceled?

      recipient = @gift_card.line_item.gift_card_recipient

      with_store_locale(current_store, @order.locale) do
        mail_template(
          # The one email that carries the code in full: it is how the card
          # reaches the person who will spend it.
          { gift_card: email_data(@gift_card, Spree::Emails::GiftCardSerializer, hide_credentials: false),
            recipient_name: recipient&.name,
            message: recipient&.message,
            sender_name: @order.full_name },
          to: recipient&.email || @order.email, store_url: current_store.storefront_url
        )
      end
    end
  end
end
