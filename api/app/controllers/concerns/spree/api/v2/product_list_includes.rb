module Spree
  module Api
    module V2
      # These includes are not picked automatically by ar_lazy_preload gem so we need to specify them manually.
      module ProductListIncludes
        def product_list_includes
          {
            option_types: [],
            product_properties: [],
            metafields: [],
            variant_images: [],
            tags: [],
            taxons: [:taxonomy],
            master: [:prices, :images, { stock_items: :stock_location }, metafields: [], option_values: []],
            variants: [:prices, :images, { stock_items: :stock_location }, metafields: [], option_values: []]
          }
        end
      end
    end
  end
end
