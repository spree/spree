module Spree
  module Api
    module V3
      class ProductFilterAvailabilitySerializer < BaseSerializer
        typelize id: :string,
                 type: "'availability'",
                 options: [:ProductFilterAvailabilityOption, multi: true]

        attributes :id, :type

        many :options, resource: proc { Spree.api.product_filter_availability_option_serializer }
      end
    end
  end
end
