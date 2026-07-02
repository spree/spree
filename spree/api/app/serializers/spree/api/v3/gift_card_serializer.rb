module Spree
  module Api
    module V3
      class GiftCardSerializer < BaseSerializer
        typelize code: :string,
                 status: :string,
                 amount: [:string, nullable: true],
                 amount_used: [:string, nullable: true],
                 amount_authorized: [:string, nullable: true],
                 amount_remaining: [:string, nullable: true],
                 display_amount: [:string, nullable: true],
                 display_amount_used: [:string, nullable: true],
                 display_amount_remaining: [:string, nullable: true],
                 currency: :string,
                 expires_at: [:string, nullable: true],
                 redeemed_at: [:string, nullable: true],
                 expired: :boolean,
                 active: :boolean

        attribute :code do |gift_card|
          gift_card.display_code
        end

        attribute :status do |gift_card|
          gift_card.display_state
        end

        attributes :currency

        # Nulled for gated (prices_hidden) guests so a gift card applied to a
        # cart can't leak balances the cart/order totals already withhold.
        money_attributes :amount, :amount_used, :amount_authorized, :amount_remaining

        attribute :display_amount do |gift_card|
          gift_card.display_amount.to_s unless params[:hide_prices]
        end

        attribute :display_amount_used do |gift_card|
          gift_card.display_amount_used.to_s unless params[:hide_prices]
        end

        attribute :display_amount_remaining do |gift_card|
          gift_card.display_amount_remaining.to_s unless params[:hide_prices]
        end

        attribute :expires_at do |gift_card|
          gift_card.expires_at&.iso8601
        end

        attribute :redeemed_at do |gift_card|
          gift_card.redeemed_at&.iso8601
        end

        attribute :expired do |gift_card|
          gift_card.expired?
        end

        attribute :active do |gift_card|
          gift_card.active?
        end

      end
    end
  end
end
