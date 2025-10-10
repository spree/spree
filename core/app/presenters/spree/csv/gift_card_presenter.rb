module Spree
  module CSV
    class GiftCardPresenter
      include Spree::CSV::MetafieldsHelper

      HEADERS = [
        'Code',
        'Amount',
        'Amount Used',
        'Amount Remaining',
        'Currency',
        'Status',
        'Expires At',
        'Customer Email',
        'Customer First Name',
        'Customer Last Name',
        'Created At',
        'Updated At'
      ].freeze

      def initialize(gift_card)
        @gift_card = gift_card
      end

      attr_accessor :gift_card

      def call
        csv = [
          gift_card.display_code,
          gift_card.display_amount,
          gift_card.display_amount_used,
          gift_card.display_amount_remaining,
          gift_card.currency,
          gift_card.display_state,
          gift_card.expires_at&.strftime('%Y-%m-%d'),
          gift_card.user&.email,
          gift_card.user&.first_name,
          gift_card.user&.last_name,
          gift_card.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
          gift_card.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
        ]

        csv += metafields_for_csv(gift_card)

        csv
      end
    end
  end
end
