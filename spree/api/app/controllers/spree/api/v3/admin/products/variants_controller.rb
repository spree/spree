module Spree
  module Api
    module V3
      module Admin
        module Products
          class VariantsController < ResourceController
            scoped_resource :products

            # PATCH /api/v3/admin/products/:product_id/variants/:id/approve
            #
            # Accepting a seller's offer on a master product, putting it on
            # sale (docs/plans/6.0-seller-master-catalog-listings.md).
            def approve
              run_review_workflow(Spree.variant_approve_workflow, note: params[:note])
            end

            # PATCH /api/v3/admin/products/:product_id/variants/:id/reject
            #
            # Turning an offer down. The reason goes back to the seller.
            def reject
              run_review_workflow(Spree.variant_reject_workflow, reason: params[:reason])
            end

            protected

            def model_class
              Spree::Variant
            end

            def serializer_class
              Spree.api.admin_variant_serializer
            end

            def set_parent
              @parent = current_store.products.find_by_prefix_id!(params[:product_id])
              authorize!(:show, @parent)
            end

            def parent_association
              :variants
            end

            def scope_includes
              [:prices, stock_levels: :stock_location]
            end

            def create_workflow
              Spree.variant_create_workflow
            end

            def update_workflow
              Spree.variant_update_workflow
            end

            # A variant belongs to a product, not directly to a store, and
            # everything nested in the payload is resolved through it — an
            # option value attaches its option type to the product, a stock
            # location is scoped to the product's store.
            def create_workflow_arguments
              { product: @parent, attributes: permitted_params }
            end

            def run_review_workflow(workflow, **arguments)
              @resource = find_resource
              authorize!(:update, @resource)

              result = workflow.call(variant: @resource, reviewer: try_spree_current_user, **arguments)

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_service_error(@resource.errors.presence || result.error)
              end
            end

            def permitted_params
              params.permit(
                *model_additional_permitted_attributes,
                # An operator's own rows move status freely; a row in review
                # is refused by Variants::Update, so a decision always runs
                # through approve/reject and records who made it.
                :status,
                :sku, :barcode,
                :cost_price, :cost_currency,
                :weight, :height, :width, :depth, :weight_unit, :dimensions_unit,
                :hs_code, :country_of_origin, :customs_description,
                :minimum_order_quantity, :order_multiple, :purchase_unit, :units_per_carton,
                :seller_id, :delivery_profile_id,
                :track_inventory, :preorderable, :preorder_ships_at, :backorder_limit, :tax_category_id, :position,
                options: [:name, :value],
                prices: [:amount, :compare_at_amount, :currency],
                stock_levels: [:stock_location_id, :count_on_hand, :backorderable]
              )
            end
          end
        end
      end
    end
  end
end
