module Spree
  module Stock
    module Splitter
      class ShippingCategory < Spree::Stock::Splitter::Base
        def split(packages)
          split_packages = packages.flat_map(&method(:split_by_category))
          return_next(split_packages)
        end

        private

        def split_by_category(package)
          # group package items by shipping category
          grouped_packages = package.contents.group_by(&method(:shipping_category_for))
          hash_to_packages(grouped_packages)
        end

        def hash_to_packages(grouped_packages)
          # select values from packages grouped by shipping categories and build new packages
          grouped_packages.values.map(&method(:build_package))
        end

        # optimization: save variant -> shipping_category correspondence
        def shipping_category_for(item)
          @item_shipping_category ||= {}
          @item_shipping_category[item.inventory_unit.variant_id] ||= item.variant.shipping_category_id
        end
      end
    end
  end
end
