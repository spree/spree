module Spree
  module Api
    module V3
      module Store
        # An address as a shopper writes it on the Store API: on a cart and in
        # their own address book. Not published on its own.
        class AddressRequestSchema < Spree::Api::V3::RequestSchema
          attribute :first_name, :string
          attribute :last_name, :string
          attribute :company, :string
          attribute :address1, :string
          attribute :address2, :string
          attribute :city, :string
          attribute :postal_code, :string
          attribute :phone, :string
          attribute :country_code, :country,
            example: 'US',
            description: 'ISO 3166-1 alpha-2 country code, such as `US` or `DE`.'
          attribute :state_code, :string,
            example: 'NY',
            description: 'ISO 3166-2 subdivision code without the country prefix, such as `CA` or `NY`.'
          attribute :state_name, :string, description: 'The state name, for countries without predefined states.'
          attribute :country_iso, :string, deprecated: 'Use `country_code`. Removed in 6.1.'
          attribute :state_abbr, :string, deprecated: 'Use `state_code`. Removed in 6.1.'
        end
      end
    end
  end
end
