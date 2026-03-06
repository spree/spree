module Spree
  module Api
    module V3
      class TaxCategorySerializer < BaseSerializer
        typelize name: :string

        attributes :name
      end
    end
  end
end
