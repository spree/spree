module Spree
  module Api
    module V3
      module Admin
        # Preloads for any controller that serializes products through
        # `Spree.api.admin_product_serializer` — the products index itself and
        # the nested membership listings (a category's or a collection's
        # products).
        #
        # The serializer walks variants, prices, stock items and media for every
        # row, so a listing without these preloads issues a few hundred queries
        # per page instead of a flat couple of dozen.
        module ProductListing
          extend ActiveSupport::Concern

          protected

          # Applied to the paginated index. The search provider builds its own
          # relation, so `ProductsController` passes this to it explicitly.
          def collection_includes
            product_listing_includes
          end

          # Applied to the single-resource lookup by the base controller.
          def scope_includes
            product_listing_includes
          end

          private

          def product_listing_includes
            [
              :tax_category,
              :product_type,
              :external_references,
              { product_publications: :channel },
              { primary_media: [attachment_attachment: :blob, poster_attachment: :blob] },
              { default_variant: [:prices, { stock_levels: [:stock_location, :active_stock_reservations] }] },
              { variants: [:prices, { stock_levels: [:stock_location, :active_stock_reservations] }] }
            ]
          end
        end
      end
    end
  end
end
