module Spree
  module V2
    module Storefront
      class CountrySerializer < BaseSerializer
        set_type :country

        attributes :iso, :iso3, :iso_name, :name, :states_required,
                   :zipcode_required

        attribute :default do |object|
          object == Spree::Country.default
        end

        has_many :states
      end
    end
  end
end
