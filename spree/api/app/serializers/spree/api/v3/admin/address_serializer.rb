module Spree
  module Api
    module V3
      module Admin
        class AddressSerializer < V3::AddressSerializer
          typelize customer_id: [:string, nullable: true],
                   owner_id: [:string, nullable: true],
                   owner_type: [:string, nullable: true],
                   latitude: [:number, nullable: true],
                   longitude: [:number, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :metadata,
                     created_at: :iso8601, updated_at: :iso8601

          # Geocoded in the background after the address is saved, so both are
          # null until that job has run — a client showing a map has to cope
          # with an address it cannot place yet.
          attribute :latitude do |address|
            address.latitude&.to_f
          end

          attribute :longitude do |address|
            address.longitude&.to_f
          end

          attribute :customer_id do |address|
            address.customer_owner&.prefixed_id
          end

          # Who the row belongs to — a customer's book, a company node's, or a
          # seller's billing address. `customer_id` above stays as the
          # customer-only shorthand the customers surface reads.
          attribute :owner_id do |address|
            address.owner&.prefixed_id
          end

          attributes :owner_type
        end
      end
    end
  end
end
