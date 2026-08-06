module Spree
  module Api
    module V3
      # Base Product Type Serializer.
      #
      # ProductType is back-office vocabulary and is NOT exposed on the Store
      # API — no endpoint, no expand, no filter. This class exists solely as the
      # parent of the Admin serializer, per the house convention that every
      # admin serializer extends a store-namespace base.
      class ProductTypeSerializer < BaseSerializer
        typelize name: :string

        attributes :name
      end
    end
  end
end
