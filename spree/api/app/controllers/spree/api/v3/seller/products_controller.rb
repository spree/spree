module Spree
  module Api
    module V3
      module Seller
        # A seller's own products.
        #
        # The first consumer of `Seller::ResourceController`, and the shape
        # every seller-side collection follows: the anchor roots `scope` in
        # `current_seller.products`, so listing, finding, updating and
        # deleting can only ever touch this seller's rows — a product id that
        # belongs to another seller is a 404, not a 403, since the caller
        # cannot tell whether it exists.
        #
        # Owned products only. Variants a seller lists against a shared
        # master-catalog product are a separate surface (the shared catalog
        # phase) and do not belong to this seller through `products`.
        #
        # What a seller may change is narrower than the operator's set. Tax
        # category and `promotionable` are marketplace configuration, and so
        # is how a product is filed: categories, collections and tags are the
        # marketplace's own merchandising, set when the operator reviews the
        # listing. The product type and the delivery profile are the seller's
        # to pick — from the marketplace's list — because the type is what
        # hands their product its option types, and the profile is what
        # decides how their goods can be shipped at all
        # (docs/plans/6.0-multi-vendor-marketplace.md, Decision 13).
        #
        # Tags are the clearest case — they are tenanted to the store
        # (`acts_as_taggable_tenant :store_id`), so a seller typing one would
        # be writing into the marketplace's shared vocabulary rather than
        # labelling their product
        # (docs/plans/6.0-multi-vendor-marketplace.md).
        class ProductsController < Seller::ResourceController
          # The statuses a seller may move a selection to, each paired with the
          # workflow that gets it there. A map rather than a status list
          # because these moves are not attribute writes: taking a listing down
          # settles the submission the seller had open, which `update_all`
          # would leave sitting as `pending` forever.
          SELLER_BULK_STATUS_WORKFLOWS = {
            'draft' => -> { Spree.product_draft_workflow },
            'archived' => -> { Spree.product_archive_workflow }
          }.freeze

          # The operator's price shape, except `currency` may be left out: the
          # store's currency is assumed (see `default_price_currencies`).
          PRICE = Spree::Api::V3::RequestSchema.new do
            string :currency, example: 'USD',
                              description: "Omit to price in the store's currency. A seller has no currency of their own."
            decimal :amount, required: true, example: '24.00',
                             description: 'A canonical decimal string (`"1234.56"`: period decimal, no grouping). The API does not parse localized input.'
            decimal :compare_at_amount, nullable: true, example: '30.00'
          end

          scoped_resource :products

          request_params 'ProductParams' do
            string :name, example: 'Hand-thrown mug'
            string :description
            string :slug, example: 'hand-thrown-mug'
            string :meta_title, :meta_description, :meta_keywords
            object :metadata
            id :product_type_id, nullable: true,
                                 description: "The marketplace's product type this product is listed against, from the product types endpoint. Null detaches it. Saving with a type seeds its option types onto the product."
            id :delivery_profile_id,
               description: "Which of the marketplace's delivery profiles the product ships under. A new product sent without one lands on the profile marked default."
            object :prices, array: true, shape: PRICE,
                            description: "Shorthand for a simple (no-options) product: per-currency prices that forward to the product's sole variant."
            # `external_url` stays out for the same reason it does on the
            # operator's endpoint: it would make the server fetch a URL the
            # caller chose.
            object :media, array: true, as: 'SellerProductMediaParams',
                           description: 'The gallery, as a whole: a file absent from the list is removed. `signed_id` attaches a fresh upload; `id` updates one already there.' do
              id :id
              string :signed_id, description: 'A `signed_id` from `POST /files`.'
              string :alt, nullable: true
              integer :position
              string :media_type, enum: Spree::Media::MEDIA_TYPES
              string :external_video_url, nullable: true
              string :poster_signed_id
              number :focal_point_x, :focal_point_y, nullable: true
              id :variant_ids, array: true, description: 'Replaces the variants this media is linked to. An empty list clears them.'
            end
            # Narrower than the operator's variant set: `seller_id` would let a
            # payload hand a variant to somebody else, and
            # `tax_category_id`/`delivery_profile_id` are marketplace
            # configuration.
            object :variants, array: true, as: 'SellerProductVariantParams',
                              description: 'The variants, as a whole: one absent from the list is removed. Pass `id` to update an existing variant.' do
              id :id
              string :sku, :barcode
              decimal :cost_price, nullable: true
              string :cost_currency
              number :weight, :height, :width, :depth, nullable: true
              string :weight_unit, enum: Spree::Variant::WEIGHT_UNITS
              string :dimensions_unit, enum: Spree::Variant::DIMENSION_UNITS
              string :hs_code, :country_of_origin, :customs_description
              integer :minimum_order_quantity, :order_multiple, nullable: true
              string :purchase_unit
              integer :units_per_carton, nullable: true, description: 'How many units fill one carton.'
              id :carton_package_type_id, nullable: true, description: 'The carton this variant is packed into: a package type of kind `carton`.'
              number :carton_weight, nullable: true, description: "What one packed carton weighs, in the variant's weight unit."
              integer :cartons_per_pallet, nullable: true, description: 'How many cartons stack on one pallet.'
              boolean :track_inventory, :preorderable
              datetime :preorder_ships_at, nullable: true,
                                           description: 'The "ships by" date shown to customers while the variant is a pre-order. Null clears it.'
              integer :backorder_limit, nullable: true,
                                        description: 'Maximum units sellable beyond available stock, capping backorders and pre-orders. Null is unlimited.'
              integer :position
              object :options, array: true, shape: Spree::Api::V3::RequestShapes::VARIANT_OPTION,
                               description: 'One pair per option type the variant takes part in (size, color).'
              object :prices, array: true, shape: PRICE, description: 'Per-currency prices. Upserted by currency.'
              object :stock_levels, array: true, shape: Spree::Api::V3::RequestShapes::STOCK_LEVEL,
                                    description: "Stock per location, at this seller's own locations only: a location belonging to anyone else is ignored."
            end
          end

          request_params 'ProductBulkSubmitParams', action: :bulk_submit do
            id :ids, array: true, required: true,
                     description: 'Only drafts and rejected listings are submitted; the rest are counted in `skipped_count`.'
          end

          request_params 'ProductBulkStatusParams', action: :bulk_status_update do
            id :ids, array: true, required: true, example: ['prod_UkLWZg9DAJ']
            string :status, required: true, enum: SELLER_BULK_STATUS_WORKFLOWS.keys,
                            description: 'A listing goes on sale only when the marketplace approves it, so there is no bulk route onto `active`.'
          end

          before_action :set_status_resource, only: [:submit, :draft, :archive]
          before_action :require_ids!, only: [:bulk_submit, :bulk_status_update, :bulk_destroy]

          # PATCH /api/v3/seller/products/:id/submit
          #
          # Asking the marketplace to put this product on sale.
          def submit
            run_status_workflow(Spree.product_propose_workflow,
                                submitted_by: try_spree_current_user)
          end

          # PATCH /api/v3/seller/products/:id/draft
          #
          # Taking a listing back down. Withdrawing your own product is not a
          # review decision, so it needs nobody's approval.
          def draft
            run_status_workflow(Spree.product_draft_workflow)
          end

          # PATCH /api/v3/seller/products/:id/archive
          def archive
            run_status_workflow(Spree.product_archive_workflow)
          end

          # POST /api/v3/seller/products/bulk_submit
          # Body: { ids: [...] }
          #
          # Asking the marketplace to review a selection.
          def bulk_submit
            authorize! :update, model_class

            # Judged on whether the product moved, not on the result: where a
            # store auto-approves, Propose commits the submission and then
            # chains into Approve, returning *its* result. A product that went
            # into review and then failed to go on sale was still submitted,
            # and counting it as skipped would tell the seller their draft was
            # not eligible when it is now sitting in review.
            render json: run_bulk(seller_bulk_scope(:update)) { |product|
              was = product.status

              Spree.product_propose_workflow.call(product: product,
                                                  submitted_by: try_spree_current_user)

              # A product Propose refused is untouched; one it accepted is in
              # review or already through it.
              product.reload.status != was
            }
          end

          # POST /api/v3/seller/products/bulk_status_update
          # Body: { ids: [...], status: 'draft' | 'archived' }
          #
          # The two moves a seller makes alone. `active` is absent by design:
          # a listing goes on sale when the operator approves it, so there is
          # no status a seller can assign that reaches it
          # (docs/plans/6.0-seller-product-submission.md).
          def bulk_status_update
            authorize! :update, model_class

            resolve_workflow = SELLER_BULK_STATUS_WORKFLOWS[params[:status].to_s]

            if resolve_workflow.nil?
              return render_error(
                code: 'invalid_status',
                message: I18n.t('spree.errors.messages.invalid_status'),
                status: :unprocessable_content
              )
            end

            # Resolved at call time, not at load: the workflow is a
            # configurable dependency, so a host that swaps it must be honoured
            # rather than frozen into the constant at boot.
            run_bulk_workflow(resolve_workflow.call)
          end

          # DELETE /api/v3/seller/products/bulk_destroy
          # Body: { ids: [...] }
          def bulk_destroy
            authorize! :destroy, model_class

            # Scoped by `:destroy` rather than reusing `bulk_collection`,
            # which is `:update`-scoped: a seller who may edit their catalog
            # but not delete from it must not delete through the bulk route.
            #
            # `Products::Destroy` exists so a store can refuse a deletion, so
            # this reports refusals like the status actions do — a product that
            # survives while the response says it was deleted is the one
            # outcome a merchant must never be shown.
            render json: run_bulk(seller_bulk_scope(:destroy)) { |product|
              Spree.product_destroy_workflow.call(product: product)
            }
          end

          protected

          def model_class
            Spree::Product
          end

          def serializer_class
            Spree.api.seller_product_serializer
          end

          # The same workflows the operator's endpoint runs, so a seller's write
          # gets the nested variant and media handling and the validate hooks
          # rather than a bare assign_attributes.
          def create_workflow
            Spree.product_create_workflow
          end

          def update_workflow
            Spree.product_update_workflow
          end

          # The workflow builds its own product, which would leave a seller's
          # listing unowned. Handing it one built through `current_seller.products`
          # keeps the seller on the record, whatever the payload claims.
          def create_workflow_arguments
            super.merge(record: build_resource)
          end

          def permitted_params
            attrs = params.permit(*permitted_attributes)

            # Assigned only when present: writing a nil `prices` or
            # `stock_levels` key reaches the association setter as nil, which
            # raises rather than meaning "leave alone".
            attrs[:prices] = default_price_currencies(attrs[:prices]) if attrs.key?(:prices)
            attrs[:product_type_id] = own_product_type_id(attrs[:product_type_id]) if attrs.key?(:product_type_id)
            attrs[:delivery_profile_id] = own_delivery_profile_id(attrs[:delivery_profile_id]) if attrs.key?(:delivery_profile_id)

            attrs[:variants] = attrs[:variants]&.map do |variant|
              variant = variant.merge(prices: default_price_currencies(variant[:prices])) if variant.key?(:prices)
              variant = variant.merge(stock_levels: own_stock_levels(variant[:stock_levels])) if variant.key?(:stock_levels)
              variant
            end

            attrs
          end

          # A price the client did not name a currency for is priced in the
          # store's. `Variant#prices=` matches base prices on the currency it is
          # handed and drops the ones missing from the payload, so a guessed
          # currency does not merely add a stray price — it removes the right
          # one. Blank counts as unnamed: an empty form field would otherwise
          # key a price on "".
          def default_price_currencies(prices)
            return prices if prices.blank?

            prices.map do |price|
              price[:currency].present? ? price : price.merge(currency: Spree::Current.currency)
            end
          end

          # A type or a profile is picked from the marketplace's own list, so
          # the id is resolved against this seller's store here rather than
          # handed to the model: a type from another store would seed its
          # option types onto the product, and a picker value that cannot
          # exist for this seller is a 404, not a validation error. Blank
          # detaches the type; a product always carries a profile, so blank
          # there is left for the model to refuse.
          def own_product_type_id(value)
            return nil if value.blank?

            current_store.product_types.find_by_prefix_id!(value).id
          end

          def own_delivery_profile_id(value)
            return nil if value.blank?

            current_store.delivery_profiles.find_by_prefix_id!(value).id
          end

          # Stock belongs to the warehouse it sits in, and a seller has their
          # own. `Variant#stock_levels=` resolves a location against the
          # product's *store*, which on a marketplace spans every seller — so a
          # payload naming somebody else's warehouse would write into it. The
          # ids are narrowed to this seller's here, where `current_seller` is
          # known; an id from elsewhere is dropped, matching how the model
          # already skips one it cannot resolve.
          def own_stock_levels(stock_levels)
            return stock_levels if stock_levels.blank?

            own_ids = current_seller.stock_locations.pluck(:id).to_set

            stock_levels.select do |level|
              id = Spree::StockLocation.decode_own_prefixed_id(level[:stock_location_id])
              id.present? && own_ids.include?(id)
            end
          end

          def collection_includes
            [:default_variant, :primary_media]
          end

          private

          # 422s when the caller omits `ids` entirely, matching the operator's
          # bulk endpoints. An explicit empty array is a no-op, which is what a
          # UI whose selection was cleared between render and submit sends.
          def require_ids!
            return if params.key?(:ids)

            render_error(
              code: 'missing_ids',
              message: 'ids is required (send an empty array to no-op).',
              status: :unprocessable_content
            )
          end

          # The selection, rooted in this seller's own catalog.
          #
          # Deliberately not the shared `BulkOperations#bulk_collection`, which
          # roots at `for_store(current_store)` — on a marketplace that is
          # every seller's catalog, so one seller's ids param would reach
          # another's products. Ids outside this seller's rows are dropped
          # silently, exactly as the operator's endpoints drop ids from
          # another store.
          #
          # @param action [Symbol] the ability action to scope by
          # @return [ActiveRecord::Relation]
          def seller_bulk_scope(action)
            current_seller.products.accessible_by(current_ability, action).
              where(id: decode_bulk_ids(params[:ids]))
          end

          # Runs a status workflow over the selection, one record at a time.
          #
          # A loop rather than `update_all`: each of these moves has side
          # effects the column write does not carry — settling an open
          # submission, announcing the change — and every workflow refuses a
          # product it cannot legally move. A refusal is skipped rather than
          # fatal, so a mixed selection still moves the rows that can move and
          # the response says how many did not
          # (docs/plans/6.0-seller-product-submission.md).
          def run_bulk_workflow(workflow, **arguments)
            render json: run_bulk(seller_bulk_scope(:update)) { |product|
              workflow.call(product: product, **arguments)
            }
          end

          # Runs a per-record operation over a selection and counts what
          # happened.
          #
          # Each record is rescued on its own. Every one of these workflows
          # opens its own transaction, so a raise partway through leaves the
          # records before it committed — letting it escape would answer a
          # half-done batch with "none of them worked", which is the one
          # description of the outcome that is certainly false. A record that
          # raises is counted as skipped, exactly like one that refused.
          #
          # @return [Hash] the response payload
          def run_bulk(records)
            done = 0
            skipped = 0

            records.each do |record|
              begin
                bulk_succeeded?(yield(record)) ? done += 1 : skipped += 1
              rescue StandardError => error
                # Surfaced rather than swallowed: a raise here is a bug or a
                # host hook misbehaving, and the count alone would never lead
                # anyone to it.
                Rails.error.report(error, handled: true, context: { product_id: record.id })
                skipped += 1
              end
            end

            payload = { product_count: done }
            # Only when it happened: a key on every response would tell clients
            # that never skip anything that nothing was skipped.
            payload[:skipped_count] = skipped if skipped.positive?
            payload
          end

          # A block may answer with the workflow's own Result, or with a plain
          # boolean where the caller decides what counts as done by looking at
          # the record rather than the result.
          def bulk_succeeded?(outcome)
            outcome.respond_to?(:success?) ? outcome.success? : !!outcome
          end

          # Inbound ids are a mix of prefixed (`prod_…`) and raw.
          #
          # Decoded through the model rather than `PrefixedId` directly, so the
          # prefix class is checked: a `variant_…` id decodes to a bare integer
          # that would otherwise match whichever product happens to carry it.
          # A mismatched prefix drops out and matches nothing, which is what a
          # mistyped id should do. Raw ids pass through for callers that send
          # them.
          def decode_bulk_ids(ids)
            Array(ids).filter_map do |id|
              next id unless Spree::PrefixedId.prefixed_id?(id)

              model_class.decode_own_prefixed_id(id)
            end
          end

          # Named apart from the base class's own resource lookup: overriding
          # that one changes every action, and these three are the only ones
          # that move a status.
          def set_status_resource
            @resource = find_resource
            # A status move is a change to the product, so it needs the write
            # key rather than one of its own — a read-only seller role cannot
            # submit, take down or archive.
            authorize!(:update, @resource)
          end

          def run_status_workflow(workflow, **arguments)
            result = workflow.call(product: @resource, **arguments)

            if result.success?
              render json: serialize_resource(@resource.reload)
            else
              render_service_error(@resource.errors.presence || result.error)
            end
          end
        end
      end
    end
  end
end
