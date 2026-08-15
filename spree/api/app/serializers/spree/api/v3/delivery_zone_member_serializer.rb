module Spree
  module Api
    module V3
      class DeliveryZoneMemberSerializer < BaseSerializer
        typelize member_type: :string, country_iso: [:string, nullable: true],
                 country_name: [:string, nullable: true],
                 state_code: [:string, nullable: true], state_name: [:string, nullable: true],
                 postal_code_prefix: [:string, nullable: true],
                 postal_code_from: [:string, nullable: true],
                 postal_code_to: [:string, nullable: true]

        attributes :member_type, :country_iso, :state_code,
                   :postal_code_prefix, :postal_code_from, :postal_code_to

        # Admin zone summaries list countries by name; without this every
        # client would have to carry its own ISO-to-name table.
        attribute :country_name do |record|
          record.country&.name
        end

        # The subdivision's name is reference data rather than something the
        # member stores, so it is looked up from its country and code.
        attribute :state_name do |record|
          Spree::IsoData.subdivision_name(record.country_iso, record.state_code) if record.state_code.present?
        end
      end
    end
  end
end
