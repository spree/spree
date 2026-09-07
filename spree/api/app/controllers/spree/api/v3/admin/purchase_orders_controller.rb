module Spree
  module Api
    module V3
      module Admin
        # Goods bought from a supplier.
        #
        # Ordered units never count toward availability: nothing here touches
        # `count_on_hand` until `receive` runs, because a merchant who has
        # ordered stock does not have it.
        #
        # Each status change is its own member action rather than a PATCH that
        # mass-assigns `status`, because receiving carries the quantities the
        # warehouse counted.
        class PurchaseOrdersController < ResourceController
          include Spree::Api::V3::Admin::ReceivableActions

          scoped_resource :purchasing

          # The base registers this for show/update/destroy; a second
          # `before_action :set_resource` replaces that registration rather than
          # adding to it, so those three are listed again here.
          before_action :set_resource, only: [:show, :update, :destroy, :mark_ordered, :receive, :cancel]

          # DELETE /api/v3/admin/purchase_orders/:id
          #
          # Only a draft. Once the order has gone to the supplier it is a
          # matter of record between two businesses, and is cancelled rather
          # than deleted.
          def destroy
            return super if @resource.draft?

            render_error(
              code: 'invalid_status',
              message: Spree.t('purchase_order.errors.only_draft_can_be_deleted'),
              status: :unprocessable_content
            )
          end

          # PATCH /api/v3/admin/purchase_orders/:id/mark_ordered
          def mark_ordered
            run_transition(Spree.purchase_order_mark_ordered_workflow)
          end

          # PATCH /api/v3/admin/purchase_orders/:id/receive
          def receive
            run_transition(Spree.purchase_order_receive_workflow,
                           items: items_for_receive([:id, :quantity_received]),
                           received_by: try_spree_current_user)
          end

          # PATCH /api/v3/admin/purchase_orders/:id/cancel
          def cancel
            run_transition(Spree.purchase_order_cancel_workflow,
                           reason: params[:reason],
                           canceler: try_spree_current_user)
          end

          protected

          def model_class
            Spree::PurchaseOrder
          end

          def serializer_class
            Spree.api.admin_purchase_order_serializer
          end

          def collection_includes
            [:supplier, :destination_location, { items: :variant }]
          end

          def create_workflow
            Spree.purchase_order_create_workflow
          end

          def update_workflow
            Spree.purchase_order_update_workflow
          end

          def workflow_record_key
            :purchase_order
          end

          def create_workflow_arguments
            {
              store: current_store,
              supplier: supplier_from_params,
              destination_location: stock_location_from(:destination_location_id),
              items: items_from_params(:quantity_ordered, :unit_cost) || [],
              currency: params[:currency],
              expected_at: params[:expected_at],
              reference: params[:reference],
              notes: params[:notes],
              created_by: try_spree_current_user
            }
          end

          def update_workflow_arguments
            {
              purchase_order: @resource,
              attributes: editable_attributes,
              items: items_from_params(:quantity_ordered, :unit_cost)
            }
          end

          # The supplier and the warehouse are resolved through the store
          # instead, since an id the payload names has to be proved to belong
          # here.
          def resource_permitted_attributes
            [:currency, :expected_at, :reference, :notes, { metadata: {} }]
          end

          def editable_attributes
            attributes = permitted_params.to_h.symbolize_keys
            attributes[:supplier] = supplier_from_params if params.key?(:supplier_id)
            if params.key?(:destination_location_id)
              attributes[:destination_location] = stock_location_from(:destination_location_id)
            end
            attributes
          end

          def scope_includes
            [{ items: :variant }]
          end

          private

          # Read through `current_store` rather than the model constant: a
          # supplier id belonging to another store must 404, which no ability
          # check would catch.
          #
          # @return [Spree::Supplier, nil]
          def supplier_from_params
            return nil if params[:supplier_id].blank?

            current_store.suppliers.accessible_by(current_ability, :show).
              find_by_prefix_id!(params[:supplier_id])
          end
        end
      end
    end
  end
end
