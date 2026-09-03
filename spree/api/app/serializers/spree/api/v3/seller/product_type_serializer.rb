module Spree
  module Api
    module V3
      module Seller
        # A product type as a seller sees it: something to list against, and
        # what picking it will bring.
        #
        # The option types are carried as **labels**, not as ids the client
        # then resolves. The operator's form looks them up against the option
        # types page it already loads, but a seller manages no option-type
        # vocabulary and has no such endpoint — sending ids alone would leave
        # the form unable to name them, and the warning it exists to show
        # would silently never appear.
        #
        # No `category_ids` (filing is the operator's, so a seller would be
        # shown a consequence they never see) and no `products_count` or
        # custom field schema, which describe how the operator maintains the
        # type rather than what listing against it does.
        class ProductTypeSerializer < V3::ProductTypeSerializer
          typelize option_type_labels: [:string, multi: true]

          attribute :option_type_labels do |product_type|
            product_type.option_types.map { |option_type| option_type.label.presence || option_type.name }.compact
          end
        end
      end
    end
  end
end
