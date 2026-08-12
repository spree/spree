module Spree
  module Api
    module V3
      class DeliveryZoneMemberSerializer < BaseSerializer
        typelize member_type: :string, country_iso: [:string, nullable: true],
                 country_name: [:string, nullable: true],
                 state_abbr: [:string, nullable: true], state_name: [:string, nullable: true],
                 postal_code_prefix: [:string, nullable: true],
                 postal_code_from: [:string, nullable: true],
                 postal_code_to: [:string, nullable: true]

        attributes :member_type, :postal_code_prefix, :postal_code_from, :postal_code_to

        attribute :country_iso do |record|
          record.country&.iso
        end

        # Admin zone summaries list countries by name; without this every
        # client would have to carry its own ISO-to-name table.
        attribute :country_name do |record|
          record.country&.name
        end

        attribute :state_abbr do |record|
          record.state&.abbr
        end

        attribute :state_name do |record|
          record.state&.name
        end
      end
    end
  end
end
