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
        # master-catalog product are their own surface —
        # `Seller::VariantsController`, rooted in `current_seller.variants` —
        # because a master product is nobody's through `products`, and a
        # whole-product `variants:` payload here would let one seller destroy
        # another's rows (docs/plans/6.0-seller-master-catalog-listings.md).
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
          include Spree::Api::V3::Seller::CatalogParams

          # The statuses a seller may move a selection to, each paired with the
          # workflow that gets it there. A map rather than a status list
          # because these moves are not attribute writes: taking a listing down
          # settles the submission the seller had open, which `update_all`
          # would leave sitting as `pending` forever.
          SELLER_BULK_STATUS_WORKFLOWS = {
            'draft' => -> { Spree.product_draft_workflow },
            'archived' => -> { Spree.product_archive_workflow }
          }.freeze

          scoped_resource :products

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
                message: Spree.t(:invalid_status, scope: 'errors.messages', default: 'Invalid status'),
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
            attrs = params.permit(
              :name, :description, :slug,
              :meta_title, :meta_description, :meta_keywords,
              :product_type_id, :delivery_profile_id,
              metadata: {},
              prices: [:amount, :compare_at_amount, :currency],
              # Inline media, the same shape the operator sends. `external_url`
              # stays out for the same reason it does there — it would make the
              # server fetch a URL the caller chose.
              media: [*Spree::Media::WRITABLE_ATTRIBUTES, :id, :signed_id, { variant_ids: [] }],
              # A seller's variants. Narrower than the operator's set:
              # `seller_id` would let a payload hand a variant to somebody
              # else, and `tax_category_id` is marketplace configuration.
              # `delivery_profile_id` rides along for read/write symmetry with
              # the serializer — the model blanks it on an owned product, so
              # the write is a no-op here and means something only on an offer
              # (docs/plans/6.0-seller-master-catalog-listings.md).
              variants: [
                :id, :sku, :barcode, :delivery_profile_id,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :hs_code, :country_of_origin, :customs_description,
                :minimum_order_quantity, :order_multiple, :purchase_unit, :units_per_carton,
                :track_inventory, :preorderable, :preorder_ships_at, :backorder_limit, :position,
                options: [:name, :value],
                prices: [:amount, :compare_at_amount, :currency],
                stock_levels: [:id, :stock_location_id, :count_on_hand, :backorderable]
              ]
            )

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
