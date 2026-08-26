module Spree
  module Api
    module V3
      module Admin
        class AddressSerializer < V3::AddressSerializer
          typelize label: [:string, nullable: true],
                   customer_id: [:string, nullable: true],
                   latitude: [:number, nullable: true],
                   longitude: [:number, nullable: true],
                   metadata: 'Record<string, unknown>'

          attributes :label, :metadata,
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
        end
      end
    end
  end
end
