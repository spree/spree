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
        # category, delivery profile and `promotionable` are marketplace
        # configuration, and so is how a product is filed: its type,
        # categories, collections and tags are the marketplace's own
        # merchandising, set when the operator reviews the listing.
        #
        # Tags are the clearest case — they are tenanted to the store
        # (`acts_as_taggable_tenant :store_id`), so a seller typing one would
        # be writing into the marketplace's shared vocabulary rather than
        # labelling their product
        # (docs/plans/6.0-multi-vendor-marketplace.md).
        class ProductsController < Seller::ResourceController
          scoped_resource :products

          before_action :set_status_resource, only: [:submit, :draft, :archive]

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
              metadata: {},
              prices: [:amount, :compare_at_amount, :currency],
              # Inline media, the same shape the operator sends. `external_url`
              # stays out for the same reason it does there — it would make the
              # server fetch a URL the caller chose.
              media: [*Spree::Media::WRITABLE_ATTRIBUTES, :id, :signed_id, { variant_ids: [] }],
              # A seller's variants. Narrower than the operator's set:
              # `seller_id` would let a payload hand a variant to somebody else,
              # and `tax_category_id`/`delivery_profile_id` are marketplace
              # configuration.
              variants: [
                :id, :sku, :barcode,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :hs_code, :country_of_origin, :customs_description,
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
