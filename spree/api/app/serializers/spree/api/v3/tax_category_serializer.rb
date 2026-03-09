module Spree
  module Api
    module V3
      class TaxCategorySerializer < BaseSerializer
        typelize name: :string

        attributes :id, :name
      end
    end
  end
end
