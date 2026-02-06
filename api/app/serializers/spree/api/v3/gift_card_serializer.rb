module Spree
  module Api
    module V3
      class GiftCardSerializer < BaseSerializer
        typelize code: :string,
                 state: :string,
                 amount: :number,
                 amount_used: :number,
                 amount_authorized: :number,
                 amount_remaining: :number,
                 display_amount: :string,
                 display_amount_used: :string,
                 display_amount_remaining: :string,
                 currency: :string,
                 expires_at: 'string | null',
                 redeemed_at: 'string | null',
                 expired: :boolean,
                 active: :boolean

        attribute :code do |gift_card|
          gift_card.display_code
        end

        attribute :state do |gift_card|
          gift_card.display_state
        end

        attributes :currency

        attribute :amount do |gift_card|
          gift_card.amount.to_f
        end

        attribute :amount_used do |gift_card|
          gift_card.amount_used.to_f
        end

        attribute :amount_authorized do |gift_card|
          gift_card.amount_authorized.to_f
        end

        attribute :amount_remaining do |gift_card|
          gift_card.amount_remaining.to_f
        end

        attribute :display_amount do |gift_card|
          gift_card.display_amount.to_s
        end

        attribute :display_amount_used do |gift_card|
          gift_card.display_amount_used.to_s
        end

        attribute :display_amount_remaining do |gift_card|
          gift_card.display_amount_remaining.to_s
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

        attributes created_at: :iso8601, updated_at: :iso8601
      end
    end
  end
end
