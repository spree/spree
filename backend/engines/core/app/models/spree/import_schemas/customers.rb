module Spree
  module ImportSchemas
    class Customers < Spree::ImportSchema
      FIELDS = [
        { name: 'email', label: 'Email', required: true },
        { name: 'first_name', label: 'First Name' },
        { name: 'last_name', label: 'Last Name' },
        { name: 'phone', label: 'Phone' },
        { name: 'accepts_email_marketing', label: 'Accepts Email Marketing' },
        { name: 'tags', label: 'Tags' },
        { name: 'company', label: 'Company' },
        { name: 'address1', label: 'Address 1' },
        { name: 'address2', label: 'Address 2' },
        { name: 'city', label: 'City' },
        { name: 'province_code', label: 'Province Code' },
        { name: 'country_code', label: 'Country Code' },
        { name: 'zip', label: 'Zip' }
      ].freeze
    end
  end
end
