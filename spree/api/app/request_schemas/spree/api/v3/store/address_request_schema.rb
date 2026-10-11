module Spree
  module Api
    module V3
      module Store
        # An address as a shopper writes it on the Store API: on a cart and in
        # their own address book. Not published on its own.
        class AddressRequestSchema < Spree::Api::V3::RequestSchema
          string :first_name, :last_name, :company, :address1, :address2, :city, :postal_code, :phone
          country :country_code, example: 'US', description: 'ISO 3166-1 alpha-2 country code, such as `US` or `DE`.'
          string :state_code, example: 'NY', description: 'ISO 3166-2 subdivision code without the country prefix, such as `CA` or `NY`.'
          string :state_name, description: 'The state name, for countries without predefined states.'
          string :country_iso, deprecated: 'Use `country_code`. Removed in 6.1.'
          string :state_abbr, deprecated: 'Use `state_code`. Removed in 6.1.'
        end
      end
    end
  end
end
