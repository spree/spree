module Spree
  module Api
    module V3
      class AddressSerializer < BaseSerializer
        def attributes
          {
            id: resource.id,
            firstname: resource.firstname,
            lastname: resource.lastname,
            full_name: resource.full_name,
            address1: resource.address1,
            address2: resource.address2,
            city: resource.city,
            zipcode: resource.zipcode,
            phone: resource.phone,
            company: resource.company,
            state_id: resource.state_id,
            state_name: resource.state_name,
            state_text: resource.state_text,
            country_id: resource.country_id,
            country_name: resource.country&.name,
            country_iso: resource.country&.iso,
            created_at: timestamp(resource.created_at),
            updated_at: timestamp(resource.updated_at)
          }
        end
      end
    end
  end
end
