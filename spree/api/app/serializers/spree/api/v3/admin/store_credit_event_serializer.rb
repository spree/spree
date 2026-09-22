module Spree
  module Api
    module V3
      module Admin
        # One line of a store credit's ledger: how the balance moved and what
        # moved it. Read-only — events are written by the credit itself.
        class StoreCreditEventSerializer < V3::StoreCreditEventSerializer
          typelize originator_type: [:string, nullable: true],
                   originator_id: [:string, nullable: true],
                   store_credit_id: :string

          attributes updated_at: :iso8601

          attribute :store_credit_id do |event|
            event.store_credit&.prefixed_id
          end

          attribute :originator_type do |event|
            Spree::Base.polymorphic_api_type(event.originator_type)
          end

          # From the columns, like the credit's own originator: a type read from
          # the column beside an id read from the association would name an
          # originator the client has no id to link to.
          attribute :originator_id do |event|
            Spree::Base.polymorphic_prefixed_id(event.originator_type, event.originator_id)
          end
        end
      end
    end
  end
end
