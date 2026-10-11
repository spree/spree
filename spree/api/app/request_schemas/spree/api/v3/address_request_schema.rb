module Spree
  module Api
    module V3
      # The writable attributes of an address (Spree::Api::V3::AddressParams).
      # Not published on its own: each endpoint includes these fields into
      # its own type, beside what it adds (default flags, a label).
      class AddressRequestSchema < Spree::Api::V3::RequestSchema
        string(*(AddressParams::ADDRESS_KEYS - %i[country_code state_code state_name zipcode]))
        string :zipcode, description: 'Legacy spelling of `postal_code`; send only one of the two.'
        country :country_code, example: 'US', description: 'ISO 3166-1 alpha-2 code, such as `US`.'
        string :state_code, example: 'NY', description: 'The state or province abbreviation, such as `NY`.'
        string :state_name, description: 'For countries without states in the database.'
      end
    end
  end
end
