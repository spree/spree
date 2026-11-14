module Spree
  module Api
    module V3
      module Seller
        # A product type as a seller sees it: something to list against, and
        # what picking it will bring.
        #
        # `option_type_ids` is what the variants builder offers as rows on a
        # new product, resolved against `GET /seller/option_types`. The labels
        # are sent as well, already named, so the form can warn which options
        # the type adds without waiting on that list.
        #
        # No `category_ids` (filing is the operator's, so a seller would be
        # shown a consequence they never see) and no `products_count` or
        # custom field schema, which describe how the operator maintains the
        # type rather than what listing against it does.
        class ProductTypeSerializer < V3::ProductTypeSerializer
          typelize option_type_ids: [:string, multi: true],
                   option_type_labels: [:string, multi: true]

          attribute :option_type_ids, &:option_type_prefixed_ids

          attribute :option_type_labels do |product_type|
            product_type.option_types.map { |option_type| option_type.label.presence || option_type.name }.compact
          end
        end
      end
    end
  end
end
