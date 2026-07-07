module Spree
  module Api
    module V3
      class ProductFilterAvailabilityOptionSerializer < BaseSerializer
        typelize id: [:string, enum: %w[in_stock out_of_stock]], count: :number

        attributes :id, :count
      end
    end
  end
end
