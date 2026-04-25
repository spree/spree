module Spree
  module Api
    module V3
      module Store
        class ProductsController < ResourceController
          include Spree::Api::V3::HttpCaching
          include Spree::Api::V3::Store::SearchProviderSupport

          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.product_serializer
          end

          # Find product by slug or prefixed ID with i18n scope for SEO-friendly URLs
          # Falls back to default locale if product is not found in the current locale
          # @return [Spree::Product]
          def find_resource
            id = params[:id]
            if id.to_s.start_with?('prod_')
              scope.find_by_prefix_id!(id)
            else
              find_with_fallback_default_locale { scope.i18n.find_by!(slug: id) }
            end
          end

          def scope
            super.active(Spree::Current.currency)
          end

          # these scopes are not automatically picked by ar_lazy_preload gem and we need to explicitly include them
          def scope_includes
            [
              primary_media: [attachment_attachment: :blob],
              master: [:prices, stock_items: :stock_location],
              variants: [:prices, stock_items: :stock_location]
            ]
          end

          # Override collection to use search provider.
          # The provider handles search, filtering, sorting, pagination, and returns a Pagy object.
          def collection
            return @collection if @collection.present?

            result = search_provider.search_and_filter(
              scope: scope.includes(collection_includes).preload_associations_lazily.accessible_by(current_ability, :show),
              query: search_query,
              filters: search_filters,
              sort: sort_param,
              page: page,
              limit: limit
            )

            @pagy = result.pagy
            @collection = result.products
          end
        end
      end
    end
  end
end
