module Spree
  module Api
    module V3
      module Admin
        class ProductsController < ResourceController
          include Spree::Api::V3::BulkOperations
          include Spree::Api::V3::Admin::ProductListing

          scoped_resource :products

          # Product is purely a catalog grouping in API v3: every purchasable
          # attribute lives on variants (docs/plans/6.0-remove-master-variant.md).
          request_params :product do |body|
            body.external_references
            body.attribute :name, :string, required: true, on: :create, example: 'Premium T-Shirt'
            body.attribute :description, :string,
              description: 'Rich text HTML. Reads come back as this (plain text) plus `description_html`.'
            body.attribute :slug, :string
            body.attribute :status, :string, choices: Spree::Product::STATUSES, open: true
            body.attribute :meta_title, :string
            body.attribute :meta_description, :string
            body.attribute :meta_keywords, :string
            body.attribute :tax_category_id, :id
            body.attribute :product_type_id, :id,
              nullable: true,
              description: 'The product type this product is created from (`pt_...`). Its option types and categories seed onto the product and its custom field definitions drive the product form. Editing the type later never rewrites existing products.'
            body.attribute :delivery_profile_id, :id,
              nullable: true,
              description: 'The delivery profile deciding how this product ships (`fp_...`); null falls back to the store default.'
            body.attribute :promotionable, :boolean
            body.attribute :tags, :array, of: :string, example: %w[eco sale]
            body.attribute :category_ids, :array, of: :id
            # Reachable with `write_products` rather than `write_collections`:
            # filing a product into its groupings is part of maintaining it.
            body.attribute :collection_ids, :array, of: :id,
              description: 'Manual collections this product belongs to. Automatic collections are kept as they are, since their rules decide membership.'
            body.attribute :metadata, :hash
            body.attribute :prices, :array, of: Spree::Api::V3::PriceRequestSchema,
              description: "Shorthand for a simple (no-options) product: per-currency prices that forward to the product's sole variant. For products with options, set prices per variant under `variants` instead. Don't pass both."
            body.attribute :custom_fields, :array, of: Spree::Api::V3::CustomFieldValueRequestSchema,
              description: 'Custom field values, each validated against its definition.'
            # `external_url` is left out on purpose: it makes the server fetch
            # a URL the caller chose, so it belongs to trusted importers.
            body.attribute :media, :array,
              as: 'ProductMediaParams',
              description: 'Media written with the product. Entries with `id` update an existing asset; entries with `signed_id` attach a fresh upload; an external video needs only its URL.' do |media_item|
              media_item.attribute :id, :id
              media_item.attribute :signed_id, :string, description: 'A `signed_id` from `files.upload()`.'
              media_item.attribute :source_media_id, :id, description: 'Copies an asset from the media library.'
              media_item.include_attributes Spree::Api::V3::MediaRequestSchema
              media_item.attribute :variant_ids, :array, of: :id,
                description: 'Replaces the variants this media is linked to. An empty list clears them.'
            end
            body.attribute :digital_assets, :array,
              as: 'ProductDigitalAssetParams',
              description: 'Downloadable files written with the product. Each entry carries a `signed_id` (an upload to private storage) or a `provider_type` (a provider-backed asset), and attaches to the default variant unless `variant_id` is given. An `id` updates that asset in place, so replaying the list does not duplicate it; removal uses the nested digital assets endpoint.' do |digital_asset|
              digital_asset.attribute :id, :id
              digital_asset.attribute :signed_id, :string
              digital_asset.attribute :variant_id, :id
              digital_asset.attribute :provider_type, :string,
                description: 'A provider shorthand from the digital asset providers endpoint.'
              digital_asset.attribute :provider_settings, :hash,
                description: "Values for the provider's settings schema, keyed by field name."
              digital_asset.attribute :authorized_clicks, :integer,
                nullable: true,
                description: "Null means the store's download settings apply."
              digital_asset.attribute :authorized_days, :integer,
                nullable: true,
                description: "Null means the store's download settings apply."
            end
            body.attribute :product_publications, :array, as: 'ProductPublicationParams' do |product_publication|
              product_publication.attribute :id, :id
              product_publication.attribute :channel_id, :id
              product_publication.attribute :published_at, :datetime, nullable: true
              product_publication.attribute :unpublished_at, :datetime, nullable: true
            end
            body.attribute :variants, :array,
              as: 'ProductVariantParams',
              description: 'Every purchasable attribute (sku, prices, stock, weight, dimensions) lives on variants. An entry without `options` upserts onto the default variant of a simple product; pass `id` to update an existing variant.' do |variant|
              variant.extends Spree::Api::V3::Admin::VariantRequestSchema
              variant.attribute :id, :id
            end
          end

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

          request_params 'ProductRejectParams', action: :reject do |body|
            body.attribute :reason, :string,
              description: 'Why the submission was turned down. Sent back to the seller.'
          end

          request_params 'ProductBulkStatusParams', action: :bulk_status_update do |body|
            body.attribute :ids, :array, of: :id, required: true, example: ['prod_UkLWZg9DAJ']
            body.attribute :status, :string,
              required: true,
              choices: Spree::Product::STATUSES,
              description: 'Products in review are skipped and counted in `skipped_in_review_count`.'
          end

          {
            'ProductBulkCategoriesParams' => [:category_ids, %i[bulk_add_to_categories bulk_remove_from_categories]],
            'ProductBulkCollectionsParams' => [:collection_ids, %i[bulk_add_to_collections bulk_remove_from_collections]],
            'ProductBulkChannelsParams' => [:channel_ids, %i[bulk_add_to_channels bulk_remove_from_channels]]
          }.each do |name, (field, actions)|
            actions.each do |action|
              request_params(name, action: action) do |body|
                body.attribute :ids, :array, of: :id, required: true
                body.attribute field, :array, of: :id, required: true
              end
            end
          end

          %i[bulk_add_tags bulk_remove_tags].each do |action|
            request_params('BulkTagsParams', action: action) { |body| body.include_attributes Spree::Api::V3::Admin::BulkTagsRequestSchema }
          end

          request_params 'ProductBulkDestroyParams', action: :bulk_destroy do |body|
            body.attribute :ids, :array, of: :id,
              required: true,
              description: 'Products the caller cannot delete are skipped.'
          end

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
                message: I18n.t('spree.errors.messages.invalid_status'),
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

          def additional_sort_fields
            Spree::SearchProvider::Base::SORT_FIELDS
          end

          def custom_field_filters?
            true
          end

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
            params.permit(*permitted_attributes).tap { |attrs| attrs.delete(:status) if review_status?(attrs[:status]) }
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
            @search_provider ||= Spree::SearchProvider::Database.new(current_store, audience: nil)
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
