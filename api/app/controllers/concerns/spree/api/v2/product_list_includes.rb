module Spree
  module Api
    module V2
      module ProductListIncludes
        def product_list_includes
          variant_includes = {
            prices: [],
            option_values: :option_type,
            images: []
          }

          {
            product_properties: [],
            option_types: [],
            variant_images: [],
            master: variant_includes,
            variants: variant_includes
          }
        end
      end
    end
  end
end
