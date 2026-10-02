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
                   outstanding: :boolean,
                   originator_type: [:string, nullable: true],
                   originator_id: [:string, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :memo, :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          string_attributes :amount_authorized

          # Answers the same question as the `outstanding` filter, so the row
          # and the filter cannot disagree.
          attribute :outstanding, &:outstanding?

          string_attributes :display_amount_authorized

          prefixed_id_attributes :customer, :created_by

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

          expandable :one, :customer, :admin_customer_serializer

          expandable :one, :created_by, :admin_admin_user_serializer
        end
      end
    end
  end
end
