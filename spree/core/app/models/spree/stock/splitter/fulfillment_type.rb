module Spree
  module Stock
    module Splitter
      # Keeps packages homogeneous by fulfillment-type set, so mixed carts
      # (physical + digital, shippable + pickup-only) split automatically.
      # Replaces the ShippingCategory and Digital splitters.
      class FulfillmentType < Spree::Stock::Splitter::Base
        def split(packages)
          split_packages = packages.flat_map { |package| split_by_fulfillment_types(package) }
          return_next(split_packages)
        end

        private

        def split_by_fulfillment_types(package)
          grouped = package.contents.group_by { |item| fulfillment_types_for(item) }
          grouped.values.map { |contents| build_package(contents) }
        end

        # optimization: save product -> fulfillment_types correspondence
        def fulfillment_types_for(item)
          @item_fulfillment_types ||= {}
          @item_fulfillment_types[item.variant.product_id] ||= item.variant.product.fulfillment_types.sort
        end
      end
    end
  end
end
