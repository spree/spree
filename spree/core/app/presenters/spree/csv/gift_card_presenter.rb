module Spree
  module CSV
    class GiftCardPresenter
      include Spree::CSV::CustomFieldsHelper

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

      def initialize(gift_card, store)
        @gift_card = gift_card
        @store = store
      end

      attr_accessor :gift_card, :store

      def call
        csv = [
          gift_card.display_code,
          gift_card.display_amount,
          gift_card.display_amount_used,
          gift_card.display_amount_remaining,
          gift_card.currency,
          gift_card.display_status,
          gift_card.expires_at&.strftime('%Y-%m-%d'),
          gift_card.customer&.email,
          gift_card.customer&.first_name,
          gift_card.customer&.last_name,
          gift_card.created_at&.strftime('%Y-%m-%d %H:%M:%S'),
          gift_card.updated_at&.strftime('%Y-%m-%d %H:%M:%S')
        ]

        csv += custom_fields_for_csv(gift_card, store)

        csv
      end
    end
  end
end
