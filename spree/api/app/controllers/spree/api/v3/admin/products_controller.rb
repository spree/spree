module Spree
  module Api
    module V3
      module Admin
        class ProductsController < ResourceController
          include Spree::Api::V3::BulkOperations

          scoped_resource :products

          before_action :require_ids!, only: [
            :bulk_status_update,
            :bulk_add_to_categories,
            :bulk_remove_from_categories,
            :bulk_add_to_channels,
            :bulk_remove_from_channels,
            :bulk_destroy
          ]

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

          # POST /api/v3/admin/products/bulk_status_update
          # Body: { ids: [...], status: 'draft' | 'active' | 'archived' }
          def bulk_status_update
            authorize! :update, model_class

            unless Spree::Product::STATUSES.include?(params[:status].to_s)
              return render_error(
                code: 'invalid_status',
                message: Spree.t(:invalid_status, scope: 'errors.messages', default: 'Invalid status'),
                status: :unprocessable_content
              )
            end

            count = bulk_collection.update_all(status: params[:status], updated_at: Time.current)
            # `update_all` skips `after_commit`, so the search index won't refresh on its own.
            bulk_collection.each(&:enqueue_search_index)

            render json: { product_count: count, status: params[:status] }
          end

          # POST /api/v3/admin/products/bulk_add_to_categories
          # Body: { ids: [...], category_ids: [...] }
          def bulk_add_to_categories
            apply_categories(Spree::Taxons::AddProducts)
          end

          # POST /api/v3/admin/products/bulk_remove_from_categories
          # Body: { ids: [...], category_ids: [...] }
          def bulk_remove_from_categories
            apply_categories(Spree::Taxons::RemoveProducts)
          end

          # POST /api/v3/admin/products/bulk_add_to_channels
          # Body: { ids: [...], channel_ids: [...] }
          def bulk_add_to_channels
            authorize! :update, model_class

            channels = scoped_channels
            product_ids = bulk_collection.distinct.ids
            channels.find_each { |channel| channel.add_products(product_ids) }

            render json: { product_count: product_ids.size, channel_count: channels.size }
          end

          # POST /api/v3/admin/products/bulk_remove_from_channels
          # Body: { ids: [...], channel_ids: [...] }
          def bulk_remove_from_channels
            authorize! :update, model_class

            channels = scoped_channels
            product_ids = bulk_collection.distinct.ids
            removed = channels.sum { |channel| channel.remove_products(product_ids) }

            render json: { product_count: product_ids.size, channel_count: channels.size, removed: removed }
          end

          # DELETE /api/v3/admin/products/bulk_destroy
          # Body: { ids: [...] }
          def bulk_destroy
            authorize! :destroy, model_class

            # Scope by `:destroy` rather than reusing `bulk_collection`
            # (which is `:update`-scoped). Otherwise an admin with update
            # rights but no destroy rights could soft-delete records.
            destroy_scope = model_class.for_store(current_store)
                                       .accessible_by(current_ability, :destroy)
                                       .where(id: decode_ids(params[:ids]))
            destroyed = destroy_scope.count(&:destroy)

            render json: { product_count: destroyed }
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
              product_publications: :channel,
              primary_media: [attachment_attachment: :blob],
              default_variant: [:prices, stock_items: [:stock_location, :active_stock_reservations]],
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
            #
            # Top-level `prices` is a convenience for simple (no-options)
            # products: the merchant doesn't need to know about the default
            # variant, so they ship prices alongside name/status and the
            # `Spree::Product#prices=` setter forwards them to it.
            params.permit(
              :name, :description, :slug, :status,
              :meta_title, :meta_description, :meta_keywords,
              :tax_category_id,
              :promotionable, :digital,
              tags: [],
              category_ids: [],
              metadata: {},
              prices: [:amount, :compare_at_amount, :currency],
              # Inline custom field values keyed by definition id. The model
              # setter (`Spree::Metafields#custom_fields=`) validates each
              # entry against its definition. We permit `value` as a scalar AND
              # as `value: []` / `value: {}` so JSON metafields round-trip
              # whether the parsed payload is an array or an object, while
              # text/number/boolean ship scalars.
              custom_fields: [:id, :custom_field_definition_id, :value, { value: [] }, { value: {} }],
              # Inline media. Entries with `id` patch an existing asset
              # (alt, position, variant_ids). Entries with `signed_id` create
              # + attach a fresh upload. Lets the dashboard ship media changes
              # alongside the rest of the product form. See
              # `Spree::Product#media=`.
              media: [:id, :signed_id, :alt, :position, :type, variant_ids: []],
              product_publications: [:id, :channel_id, :published_at, :unpublished_at],
              variants: [
                :id, :sku, :barcode,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :track_inventory, :preorderable, :preorder_ships_at, :backorder_limit, :tax_category_id, :position,
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

          # Mirrors `Spree::Admin::ProductsController#after_bulk_tags_change`:
          # tag changes can flip automatic-taxon matches, and `Tags::Bulk*`
          # touch records via `touch_all` (which skips `after_commit`), so the
          # search index needs an explicit kick.
          def after_bulk_tags_change
            Spree::Product.bulk_auto_match_taxons(current_store, bulk_collection.ids)
            bulk_collection.each(&:enqueue_search_index)
          end

          def bulk_record_count_key
            :product_count
          end

          def apply_categories(service)
            authorize! :update, model_class

            category_ids = decode_ids(params[:category_ids])
            categories = current_store.categories.
                         accessible_by(current_ability, :update).where(id: category_ids)

            service.call(taxons: categories, products: bulk_collection)
            Spree::Product.bulk_auto_match_taxons(current_store, bulk_collection.ids)

            render json: { product_count: bulk_collection.size, category_count: categories.size }
          end

          def scoped_channels
            channel_ids = decode_ids(params[:channel_ids])
            current_store.channels.accessible_by(current_ability, :manage).where(id: channel_ids)
          end
        end
      end
    end
  end
end
