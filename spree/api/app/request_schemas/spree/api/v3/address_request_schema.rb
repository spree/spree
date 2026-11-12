module Spree
  module Api
    module V3
      # The writable attributes of an address, wherever it hangs. One list
      # rather than one per endpoint: an address is the same record on every
      # write path, so a column added on one but missed on another would be
      # dropped silently. Not published on its own: each endpoint includes
      # these attributes into its own type, beside what it adds.
      class AddressRequestSchema < Spree::Api::V3::RequestSchema
        attribute :first_name, :string
        attribute :last_name, :string
        attribute :company, :string
        attribute :address1, :string
        attribute :address2, :string
        attribute :city, :string
        attribute :postal_code, :string
        attribute :phone, :string
        attribute :label, :string
        attribute :country_code, :country, example: 'US', description: 'ISO 3166-1 alpha-2 code, such as `US`.'
        attribute :state_code, :string,
          example: 'NY',
          description: 'The state or province abbreviation, such as `NY`.'
        attribute :state_name, :string, description: 'For countries without states in the database.'
      end
    end
  end
end
