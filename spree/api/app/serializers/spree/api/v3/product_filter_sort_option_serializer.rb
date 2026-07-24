module Spree
  module Api
    module V3
      class ProductFilterSortOptionSerializer < BaseSerializer
        typelize id: :string, label: 'string | null'

        attributes :id, :label
      end
    end
  end
end
