module Spree
  module Api
    module V3
      module Admin
        # Admin serializer extends the store-facing one with operational
        # context the admin UI needs: who the card was issued to (customer),
        # who issued it (admin), and the orders that consumed it.
        class GiftCardSerializer < V3::GiftCardSerializer
          # The Admin API has no guest gating — money fields inherited from the
          # store serializer are always present, so override their nullability.
          typelize amount: [:string, nullable: false], amount_used: [:string, nullable: false],
                   amount_authorized: [:string, nullable: false], amount_remaining: [:string, nullable: false],
                   display_amount: [:string, nullable: false], display_amount_used: [:string, nullable: false],
                   display_amount_remaining: [:string, nullable: false]

          typelize customer_id: [:string, nullable: true],
                   created_by_id: [:string, nullable: true]

          attributes created_at: :iso8601, updated_at: :iso8601

          attribute :customer_id do |gift_card|
            gift_card.user&.prefixed_id
          end

          attribute :created_by_id do |gift_card|
            gift_card.created_by&.prefixed_id
          end

          # Customer the card was issued to. Gated behind `expand?` to keep
          # the list payload thin — the SPA's list view passes
          # `expand=customer,created_by` to populate the row chips.
          one :user,
              key: :customer,
              resource: proc { Spree.api.admin_customer_serializer },
              if: proc { expand?('customer') }

          # Admin who issued the card.
          one :created_by,
              resource: proc { Spree.api.admin_admin_user_serializer },
              if: proc { expand?('created_by') }

          # Batch the card was issued as part of (bulk-issue flow). The
          # `Spree::GiftCard#batch` association is keyed off
          # `gift_card_batch_id`; we rename the JSON field to match that
          # column for read/write symmetry.
          one :batch,
              key: :gift_card_batch,
              resource: proc { Spree.api.admin_gift_card_batch_serializer },
              if: proc { expand?('gift_card_batch') }

          # Orders that consumed the card. Detail-only — pass `expand=orders`.
          many :orders,
               resource: proc { Spree.api.admin_order_serializer },
               if: proc { expand?('orders') }
        end
      end
    end
  end
end
