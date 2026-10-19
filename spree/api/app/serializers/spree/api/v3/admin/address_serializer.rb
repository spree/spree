module Spree
  module Api
    module V3
      module Admin
        class AddressSerializer < V3::AddressSerializer
          # The Store API keeps these deprecated names until 6.1.
          %i[state_abbr country_iso].each { |key| _attributes.delete(key) }

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

          prefixed_id_attributes customer_id: :customer_owner

          # Who the row belongs to — a customer's book, a company node's, or a
          # seller's billing address. `customer_id` above stays as the
          # customer-only shorthand the customers surface reads.
          prefixed_id_attributes :owner

          # Only when there is an owner to name. The copy a purchase keeps of a
          # company site retains the owner type so it stays recognisably a
          # business address, but it belongs to nobody's book — reporting an
          # owner type beside a null owner would describe ownership it has not
          # got.
          attribute :owner_type do |address|
            Spree::Base.polymorphic_api_type(address.owner_type) if address.owner_id.present?
          end
        end
      end
    end
  end
end
