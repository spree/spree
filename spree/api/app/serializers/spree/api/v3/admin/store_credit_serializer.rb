module Spree
  module Api
    module V3
      module Admin
        class StoreCreditSerializer < V3::StoreCreditSerializer
          typelize customer_id: [:string, nullable: true],
                   created_by_id: [:string, nullable: true],
                   memo: [:string, nullable: true],
                   amount_authorized: :string,
                   display_amount_authorized: :string,
                   originator_type: [:string, nullable: true],
                   originator_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :memo, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          attribute :amount_authorized do |store_credit|
            store_credit.amount_authorized.to_s
          end

          attribute :display_amount_authorized do |store_credit|
            store_credit.display_amount_authorized.to_s
          end

          attribute :customer_id do |store_credit|
            store_credit.customer&.prefixed_id
          end

          attribute :created_by_id do |store_credit|
            store_credit.created_by&.prefixed_id
          end

          # Why the credit exists: the return, exchange, claim or gift card
          # that issued it, or null when an admin issued it by hand. The type
          # is the polymorphic shorthand (`return`, `gift_card`), never a Ruby
          # class name.
          attribute :originator_type do |store_credit|
            Spree::Base.polymorphic_api_type(store_credit.originator_type)
          end

          attribute :originator_id do |store_credit|
            store_credit.originator&.prefixed_id
          end

          one :customer,
              resource: proc { Spree.api.admin_customer_serializer },
              if: proc { expand?('customer') }

          one :created_by,
              resource: proc { Spree.api.admin_admin_user_serializer },
              if: proc { expand?('created_by') }
        end
      end
    end
  end
end
