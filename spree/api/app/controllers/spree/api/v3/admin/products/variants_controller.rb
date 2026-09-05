module Spree
  module Api
    module V3
      module Admin
        module Products
          class VariantsController < ResourceController
            scoped_resource :products

            request_params :variant do |body|
              body.extends Spree::Api::V3::Admin::VariantRequestSchema
              body.external_references
              body.require_attributes :options, on: :create
              body.describe_attribute :options, 'One pair per option type the variant takes part in (size, color). Option types and values are created when missing. On update, omit to leave the option values untouched.'
              # An operator's own rows move status freely; a row in review is
              # refused by Variants::Update, so a decision always runs through
              # approve/reject and records who made it.
              body.attribute :status, :string, choices: Spree::Variant.statuses.map(&:to_s), open: true
            end

            request_params 'VariantApproveParams', action: :approve do |body|
              body.attribute :note, :string, description: 'An optional note sent back to the seller.'
            end

            request_params 'VariantRejectParams', action: :reject do |body|
              body.attribute :reason, :string, description: 'Why the offer was turned down. Sent back to the seller.'
            end

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

            # `active_stock_reservations` is what lets the quantifier count
            # held stock in memory; without it the serializer's availability
            # column sums reservations once per variant.
            def scope_includes
              [:prices, { stock_levels: [:stock_location, :active_stock_reservations] }]
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
              params.permit(*permitted_attributes).tap { |attrs| attrs.delete(:status) if review_status?(attrs[:status]) }
            end

            # A review status is an outcome, not a value to assign: `proposed`
            # means a seller asked, and `rejected` means somebody decided.
            # Both are reached through the workflows behind `approve`/`reject`,
            # which record who decided and settle the submission row — writing
            # one here would leave a seller looking at a rejected offer with no
            # reason and no trail
            # (docs/plans/6.0-seller-master-catalog-listings.md).
            def review_status?(status)
              status.present? && Spree::Variant::REVIEW_STATUSES.include?(status.to_s)
            end
          end
        end
      end
    end
  end
end
