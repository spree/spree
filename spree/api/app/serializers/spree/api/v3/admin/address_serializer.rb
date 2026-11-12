module Spree
  module Api
    module V3
      module Admin
        class AddressSerializer < V3::AddressSerializer
          # The Store API keeps these deprecated names until 6.1.
          %i[state_abbr country_iso].each { |key| _attributes.delete(key) }

          typelize customer_id: [:string, nullable: true],
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

          prefixed_id_attributes customer_id: :customer_owner

          one :owner, resource: proc { Spree.api.admin_address_owner_serializer }

          expandable_custom_fields admin: true
        end
      end
    end
  end
end
