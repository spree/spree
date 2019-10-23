module Spree
  module V2
    module Storefront
      class CountrySerializer < BaseSerializer
        set_type :country

        attributes :iso, :iso3, :iso_name, :name, :states_required,
                   :zipcode_required

        attribute :default do |object|
          object.default?
        end

        has_many :states, if: proc { |_record, params| params && params[:include_states] }
      end
    end
  end
end
