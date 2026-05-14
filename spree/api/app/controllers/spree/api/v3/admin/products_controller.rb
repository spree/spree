module Spree
  module Api
    module V3
      module Admin
        class ProductsController < ResourceController
          scoped_resource :products

          # POST /api/v3/admin/products/:id/clone
          def clone
            @resource = find_resource
            authorize!(:create, @resource)

            result = @resource.duplicate
            if result.success?
              render json: serialize_resource(result.value), status: :created
            else
              render_service_error(result.error)
            end
          end

          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.admin_product_serializer
          end

          def scope_includes
            [
              :tax_category,
              primary_media: [attachment_attachment: :blob],
              master: [:prices, stock_items: [:stock_location, :active_stock_reservations]],
              variants: [:prices, stock_items: [:stock_location, :active_stock_reservations]]
            ]
          end

          # Use SearchProvider::Database for collection to handle price/best_selling
          # sorting correctly (counts before sorting, avoiding PG/Mobility issues).
          def collection
            return @collection if @collection.present?

            filters = params[:q]&.to_unsafe_h || params[:q] || {}
            # Decode Stripe-style prefixed IDs in `*_id_in`/`id_eq`/etc. so SPA
            # filters can pass `prod_…` keys; the search provider expects raw
            # IDs because it goes straight to Ransack on the underlying scope.
            filters = decode_prefixed_id_predicates(filters)
            # `q[search]` is the global text-search predicate; pass it through
            # the provider's `query` arg so it invokes `Product.search` rather
            # than being treated as a Ransack predicate (which gets stripped
            # by the provider's filter sanitizer).
            query = filters['search'] || filters[:search]

            result = search_provider.search_and_filter(
              scope: scope.includes(collection_includes).preload_associations_lazily.accessible_by(current_ability, :show),
              query: query,
              filters: filters,
              sort: sort_param,
              page: page,
              limit: limit
            )

            @pagy = result.pagy
            @collection = result.products
          end

          def permitted_params
            # Product is purely a catalog grouping in API v3. All purchasable
            # attributes (sku, barcode, price, weight, dimensions, stock,
            # track_inventory) live on variants. See
            # docs/plans/6.0-remove-master-variant.md.
            params.permit(
              :name, :description, :slug, :status,
              :available_on, :discontinue_on, :make_active_at,
              :meta_title, :meta_description, :meta_keywords,
              :tax_category_id,
              :promotionable, :digital,
              tags: [],
              category_ids: [],
              metadata: {},
              variants: [
                :id, :sku, :barcode,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :track_inventory, :tax_category_id, :position,
                options: [:name, :value],
                prices: [:amount, :compare_at_amount, :currency],
                stock_items: [:id, :stock_location_id, :count_on_hand, :backorderable]
              ]
            )
          end

          private

          def search_provider
            @search_provider ||= Spree::SearchProvider::Database.new(current_store)
          end
        end
      end
    end
  end
end
