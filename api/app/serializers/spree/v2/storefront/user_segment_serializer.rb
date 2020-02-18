module Spree
  module V2
    module Storefront
      class UserSegmentSerializer < BaseSerializer
        set_type :user

        attribute :type do |object| 'identify' end
        attribute :userId, &:id
        attribute :traits do |object|
          {
            firstName: object&.first_name,
            lastName:  object&.last_name,
            name:      object&.full_name,
            phone:     object&.phone,
            createdAt: object&.created_at,
            logins:    object&.sign_in_count,
            address: {
              street: [object&.bill_address&.address1, object&.bill_address&.address2].compact.join(' '),
              city: object&.bill_address&.city,
              state: object&.bill_address&.state_abbr,
              country: object&.bill_address&.country_iso3,
              postalCode: object&.bill_address&.zipcode
            }
          }
        end
      end
    end
  end
end
