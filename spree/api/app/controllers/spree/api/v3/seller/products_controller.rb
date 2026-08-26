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
        # What a seller may change is narrower than the operator's set:
        # `tax_category_id` and `delivery_profile_id` are marketplace
        # configuration and stay with the operator, as does `promotionable`.
        class ProductsController < Seller::ResourceController
          scoped_resource :products

          before_action :set_status_resource, only: [:submit, :draft, :archive]

          # PATCH /api/v3/seller/products/:id/submit
          #
          # Asking the marketplace to put this product on sale.
          def submit
            run_status_workflow(Spree.product_propose_workflow)
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
              :product_type_id,
              tags: [],
              category_ids: [],
              collection_ids: [],
              metadata: {},
              prices: [:amount, :compare_at_amount, :currency],
              custom_fields: [:id, :custom_field_definition_id, :value, { value: [] }, { value: {} }],
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

            # A price the client did not name a currency for is priced in the
            # store's. `Variant#prices=` matches base prices on the currency it
            # is handed and drops the ones missing from the payload, so a
            # guessed currency does not merely add a stray price — it removes
            # the right one. Blank counts as unnamed: an empty form field would
            # otherwise key a price on "".
            return attrs if attrs[:prices].blank?

            attrs[:prices] = attrs[:prices].map do |price|
              price[:currency].present? ? price : price.merge(currency: Spree::Current.currency)
            end

            attrs
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

          def run_status_workflow(workflow)
            result = workflow.call(product: @resource)

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
