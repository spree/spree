module Spree
  module Api
    module V3
      module Admin
        class StoreCreditSerializer < V3::StoreCreditSerializer
          without_formatted_money

          typelize customer_id: [:string, nullable: true],
                   created_by_id: [:string, nullable: true],
                   created_by_type: [:string, nullable: true, enum: Spree::Actor::BUILT_IN_KINDS, enum_type_name: 'ActorKind'],
                   memo: [:string, nullable: true],
                   amount: [:string, nullable: false], amount_used: [:string, nullable: false],
                   amount_remaining: [:string, nullable: false],
                   amount_authorized: [:string, nullable: false],
                   outstanding: :boolean,
                   originator_type: [:string, nullable: true],
                   originator_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :memo, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          money_attributes :amount_authorized
          # Answers the same question as the `outstanding` filter, so the row
          # and the filter cannot disagree.
          attribute :outstanding, &:outstanding?

          # money_attributes types its fields nullable for gated guests; the
          # Admin API never gates prices.
          typelize amount_authorized: [:string, nullable: false]
          prefixed_id_attributes :customer
          actor_attributes :created_by

          # Why the credit exists: the return, exchange, claim or gift card
          # that issued it, or null when an admin issued it by hand. The type
          # is the polymorphic shorthand (`return`, `gift_card`), never a Ruby
          # class name.
          #
          # Both read the columns rather than the association: returns, claims
          # and exchanges are paranoid, so loading the record answers nil once
          # it is soft-deleted — which would leave a type naming an originator
          # beside a null id, and a client rendering "Return" for something it
          # cannot link to.
          attribute :originator_type do |store_credit|
            Spree::Base.polymorphic_api_type(store_credit.originator_type)
          end

          attribute :originator_id do |store_credit|
            Spree::Base.polymorphic_prefixed_id(store_credit.originator_type, store_credit.originator_id)
          end

          one :customer,
              resource: proc { Spree.api.admin_customer_serializer },
              if: proc { expand?('customer') }

          expandable_custom_fields admin: true
        end
      end
    end
  end
end
