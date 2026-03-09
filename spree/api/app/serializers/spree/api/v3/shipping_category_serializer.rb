module Spree
  module Api
    module V3
      class ShippingCategorySerializer < BaseSerializer
        typelize name: :string

        attributes :id, :name
      end
    end
  end
end
