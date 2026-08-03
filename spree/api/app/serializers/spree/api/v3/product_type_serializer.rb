module Spree
  module Api
    module V3
      # Store API Product Type Serializer
      # Read-only expand on products — customers only see the type's name.
      class ProductTypeSerializer < BaseSerializer
        typelize name: :string

        attributes :name
      end
    end
  end
end
