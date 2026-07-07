module Spree
  module Api
    module V3
      class ProductFilterCategorySerializer < BaseSerializer
        typelize id: :string,
                 type: "'category'",
                 options: [:ProductFilterCategoryOption, multi: true]

        attributes :id, :type

        many :options, resource: proc { Spree.api.product_filter_category_option_serializer }
      end
    end
  end
end
