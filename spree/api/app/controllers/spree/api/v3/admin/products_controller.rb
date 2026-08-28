module Spree
  module Api
    module V3
      module Admin
        class ProductsController < ResourceController
          include Spree::Api::V3::BulkOperations
          include Spree::Api::V3::Admin::ProductListing

          scoped_resource :products

          before_action :require_ids!, only: [
            :bulk_status_update,
            :bulk_add_to_categories,
            :bulk_remove_from_categories,
            :bulk_add_to_collections,
            :bulk_remove_from_collections,
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

          # PATCH /api/v3/admin/products/:id/approve
          #
          # Accepting a product a seller submitted, putting it on sale.
          def approve
            run_review_workflow(Spree.product_approve_workflow)
          end

          # PATCH /api/v3/admin/products/:id/reject
          #
          # Turning a submission down. The reason goes back to the seller.
          def reject
            run_review_workflow(Spree.product_reject_workflow, reason: params[:reason])
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

            # Products in review are excluded rather than refused: a bulk
            # activate over a mixed selection should still do the plain ones,
            # and moving the rest is `approve`/`reject`, which records who
            # decided (docs/plans/6.0-seller-product-submission.md).
            movable = bulk_collection.where.not(status: Spree::Product::REVIEW_STATUSES)
            skipped = bulk_collection.where(status: Spree::Product::REVIEW_STATUSES).count

            count = movable.update_all(status: params[:status], updated_at: Time.current)
            # `update_all` skips `after_commit`, so the search index won't refresh on its own.
            movable.each(&:enqueue_search_index)

            payload = { product_count: count, status: params[:status] }
            # Only when it happened: a key on every response would say
            # "nothing was skipped" to clients that never skip anything.
            payload[:skipped_in_review_count] = skipped if skipped.positive?

            render json: payload
          end

          # POST /api/v3/admin/products/bulk_add_to_categories
          # Body: { ids: [...], category_ids: [...] }
          def bulk_add_to_categories
            apply_categories(Spree::Categories::AddProducts)
          end

          # POST /api/v3/admin/products/bulk_remove_from_categories
          # Body: { ids: [...], category_ids: [...] }
          def bulk_remove_from_categories
            apply_categories(Spree::Categories::RemoveProducts)
          end

          # POST /api/v3/admin/products/bulk_add_to_collections
          # Body: { ids: [...], collection_ids: [...] }
          def bulk_add_to_collections
            apply_collections(Spree::Collections::AddProducts)
          end

          # POST /api/v3/admin/products/bulk_remove_from_collections
          # Body: { ids: [...], collection_ids: [...] }
          def bulk_remove_from_collections
            apply_collections(Spree::Collections::RemoveProducts)
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

          # DELETE /api/v3/admin/products/:id
          def destroy
            result = Spree.product_destroy_workflow.call(product: @resource)

            if result.success?
              head :no_content
            else
              render_result_error(result)
            end
          end

          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.admin_product_serializer
          end

          def create_workflow
            Spree.product_create_workflow
          end

          def update_workflow
            Spree.product_update_workflow
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
              *model_additional_permitted_attributes,
              :name, :description, :slug, :status,
              :meta_title, :meta_description, :meta_keywords,
              :tax_category_id, :product_type_id, :delivery_profile_id,
              :promotionable,
              tags: [],
              category_ids: [],
              # Manual collection membership only — the model setter ignores
              # incoming automatic collections and preserves the product's
              # existing ones, since those are materialized from their rules.
              #
              # Deliberately reachable with `write_products` rather than
              # `write_collections`: filing a product into its groupings is part
              # of maintaining the product, which is why `category_ids` and the
              # bulk membership endpoints have always worked this way too.
              # Creating or configuring a collection still needs
              # `write_collections`.
              collection_ids: [],
              metadata: {},
              prices: [:amount, :compare_at_amount, :currency],
              # Inline custom field values keyed by definition id. The model
              # setter (`Spree::HasCustomFields#custom_fields=`) validates each
              # entry against its definition. We permit `value` as a scalar AND
              # as `value: []` / `value: {}` so JSON custom_fields round-trip
              # whether the parsed payload is an array or an object, while
              # text/number/boolean ship scalars.
              custom_fields: [:id, :custom_field_definition_id, :value, { value: [] }, { value: {} }],
              # Inline media. Entries with `id` patch an existing asset.
              # Entries with `signed_id` create + attach a fresh upload; an
              # external video creates with a URL and no file. Lets the
              # dashboard ship media changes alongside the rest of the product
              # form. See `Spree::Products::NestedAttributes`.
              #
              # `external_url` is deliberately not permitted here: it makes the
              # server fetch a URL the caller chose, so it belongs to trusted
              # importers rather than to a request body.
              media: [*Spree::Media::WRITABLE_ATTRIBUTES, :id, :signed_id, :source_media_id, { variant_ids: [] }],
              # Inline digital files, so a new product ships its downloadable
              # files in the same request. Additive: an entry carries a
              # `signed_id` (uploaded file) or a `provider_type` (provider-backed
              # asset), and an `id` patches that asset in place rather than
              # building a duplicate — so replaying a product's list on update
              # does not accumulate copies. Removal uses the nested
              # digital_assets endpoint. See `Spree::Product#digital_assets=`.
              digital_assets: [:id, :signed_id, :variant_id, :provider_type, :authorized_clicks, :authorized_days, provider_settings: {}],
              product_publications: [:id, :channel_id, :published_at, :unpublished_at],
              variants: [
                :id, :sku, :barcode,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :hs_code, :country_of_origin, :customs_description,
                :seller_id, :delivery_profile_id,
                :track_inventory, :preorderable, :preorder_ships_at, :backorder_limit, :tax_category_id, :position,
                options: [:name, :value],
                prices: [:amount, :compare_at_amount, :currency],
                stock_levels: [:id, :stock_location_id, :count_on_hand, :backorderable]
              ]
            ).tap { |attrs| attrs.delete(:status) if review_status?(attrs[:status]) }
          end

          # A review status is an outcome, not a value to assign: `proposed`
          # means a seller asked, and `rejected` means somebody decided. Both
          # are reached through the workflows behind `approve`/`reject`, so a
          # status naming one here is dropped rather than written — the same
          # reason `bulk_status_update` validates against `STATUSES` and not
          # the full list (docs/plans/6.0-seller-product-submission.md).
          def review_status?(status)
            status.present? && Spree::Product::REVIEW_STATUSES.include?(status.to_s)
          end

          private

          # Approving and rejecting are edits to the catalog, so they answer to
          # the same key as any other product write.
          def run_review_workflow(workflow, **arguments)
            @resource = find_resource
            authorize!(:update, @resource)

            result = workflow.call(product: @resource, reviewer: try_spree_current_user, **arguments)

            if result.success?
              render json: serialize_resource(@resource.reload)
            else
              render_service_error(@resource.errors.presence || result.error)
            end
          end

          def search_provider
            @search_provider ||= Spree::SearchProvider::Database.new(current_store)
          end

          # Tag changes can flip automatic-collection matches, and `Tags::Bulk*`
          # touch records via `touch_all` (which skips `after_commit`), so the
          # search index needs an explicit kick.
          def after_bulk_tags_change
            Spree::Product.bulk_auto_match_collections(current_store, bulk_collection.ids)
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

            service.call(categories: categories, products: bulk_collection)

            render json: { product_count: bulk_collection.size, category_count: categories.size }
          end

          def apply_collections(service)
            authorize! :update, model_class

            # Only manual collections accept curation — automatic membership is
            # rebuilt from rules, so a manual add/remove would be lost on the next
            # regeneration (mirrors apply_categories, whose association is manual).
            collection_ids = decode_ids(params[:collection_ids])
            collections = current_store.collections.manual.
                          accessible_by(current_ability, :update).where(id: collection_ids)

            service.call(collections: collections, products: bulk_collection)

            render json: { product_count: bulk_collection.size, collection_count: collections.size }
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
