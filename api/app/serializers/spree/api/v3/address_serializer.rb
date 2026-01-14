module Spree
  module Api
    module V3
      class AddressSerializer < BaseSerializer
        attributes :id, :firstname, :lastname, :full_name, :address1, :address2,
                   :city, :zipcode, :phone, :company, :state_id, :state_name,
                   :state_text, :country_id,
                   created_at: :iso8601, updated_at: :iso8601

        attribute :country_name do |address|
          address.country&.name
        end

        attribute :country_iso do |address|
          address.country&.iso
        end
      end
    end
  end
end
