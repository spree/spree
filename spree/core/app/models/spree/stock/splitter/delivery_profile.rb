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

        # Keyed on the product AND the variant's own override, rather than the
        # product alone: a variant may override the profile, so two sellers
        # sharing a product ship on their own terms, and a product-only key
        # would have packed the second seller's goods with the first seller's
        # shipping configuration.
        #
        # The override is read as the raw column, so the many variants that
        # simply inherit still share one slot and one resolution.
        def profile_id_for(item)
          @item_profiles ||= {}
          variant = item.variant
          @item_profiles[[variant.product_id, variant[:delivery_profile_id]]] ||= variant.delivery_profile&.id
        end
      end
    end
  end
end
