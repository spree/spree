module Spree
  module Stock
    module Splitter
      # Keeps packages homogeneous by delivery profile, so mixed carts
      # (default-profile goods + oversized + digital) split automatically and
      # each package quotes against exactly its profile's methods.
      class DeliveryProfile < Spree::Stock::Splitter::Base
        def split(packages)
          split_packages = packages.flat_map { |package| split_by_profile(package) }
          return_next(split_packages)
        end

        private

        def split_by_profile(package)
          grouped = package.contents.group_by { |item| profile_id_for(item) }
          grouped.values.map { |contents| build_package(contents) }
        end

        # optimization: save product -> profile correspondence
        def profile_id_for(item)
          @item_profiles ||= {}
          @item_profiles[item.variant.product_id] ||= item.variant.product.resolved_delivery_profile&.id
        end
      end
    end
  end
end
