module Spree
  module Stock
    module Splitter
      class ShippingCategory < Spree::Stock::Splitter::Base
        def split(packages)
          split_packages = []
          packages.each do |package|
            split_packages += split_by_category(package)
          end
          return_next split_packages
        end

        private

        def split_by_category(package)
          categories = Hash.new { |hash, key| hash[key] = [] }
          package.contents.each do |item|
            categories[shipping_category_for(item)] << item
          end
          hash_to_packages(categories)
        end

        def hash_to_packages(categories)
          packages = []
          categories.each do |_id, contents|
            packages << build_package(contents)
          end
          packages
        end

        def shipping_category_for(item)
          @item_shipping_category ||= {}
          @item_shipping_category[item.inventory_unit.variant_id] ||= item.variant.shipping_category_id
        end
      end
    end
  end
end
