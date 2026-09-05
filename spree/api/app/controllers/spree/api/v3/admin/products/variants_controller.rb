module Spree
  module Api
    module V3
      module Admin
        module Products
          class VariantsController < ResourceController
            include Spree::Api::V3::StatusActions

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
              set_status_resource
              run_status_workflow(Spree.variant_approve_workflow,
                                  reviewer: try_spree_current_user, note: params[:note])
            end

            # PATCH /api/v3/admin/products/:product_id/variants/:id/reject
            #
            # Turning an offer down. The reason goes back to the seller.
            def reject
              set_status_resource
              run_status_workflow(Spree.variant_reject_workflow,
                                  reviewer: try_spree_current_user, reason: params[:reason])
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

            # `submissions` rides along because the serializer's review expand
            # reads the latest row per variant, and `active_stock_reservations`
            # lets the quantifier count held stock in memory — without either,
            # the list costs one query per variant.
            def scope_includes
              [:prices, :submissions, { stock_levels: [:stock_location, :active_stock_reservations] }]
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

            def permitted_params
              params.permit(*permitted_attributes).tap { |attrs| attrs.delete(:status) if review_status?(attrs[:status]) }
            end
          end
        end
      end
    end
  end
end
