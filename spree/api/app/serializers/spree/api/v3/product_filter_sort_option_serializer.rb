module Spree
  module Api
    module V3
      class ProductFilterSortOptionSerializer < BaseSerializer
        typelize id: :string

        attributes :id
      end
    end
  end
end
