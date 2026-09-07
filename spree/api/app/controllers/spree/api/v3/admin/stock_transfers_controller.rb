module Spree
  module Api
    module V3
      module Admin
        # Stock moving between two of the merchant's own warehouses.
        #
        # `create` persists a draft; nothing moves until the transfer is marked
        # in transit. Receiving from a supplier is a
        # {Spree::Api::V3::Admin::PurchaseOrdersController} order, not a
        # transfer with a missing source.
        #
        # Every status change is its own member action rather than a PATCH that
        # mass-assigns `status`, because each one is a workflow with its own
        # arguments — receiving carries the quantities the warehouse counted,
        # cancelling carries what happens to units already in flight.
        class StockTransfersController < ResourceController
          include Spree::Api::V3::Admin::ReceivableActions

          scoped_resource :stock

          # The base registers this for show/update/destroy; a second
          # `before_action :set_resource` replaces that registration rather than
          # adding to it, so those three are listed again here.
          before_action :set_resource, only: [:show, :update, :destroy, :mark_ready, :mark_in_transit, :receive, :cancel]

          # DELETE /api/v3/admin/stock_transfers/:id
          #
          # A draft is the only transfer a merchant may throw away: past that
          # it describes a box that physically exists, which is cancelled
          # rather than deleted.
          def destroy
            return super if @resource.draft?

            render_error(
              code: 'invalid_status',
              message: Spree.t('stock_transfer.errors.only_draft_can_be_deleted'),
              status: :unprocessable_content
            )
          end

          # PATCH /api/v3/admin/stock_transfers/:id/mark_ready
          def mark_ready
            run_transition(Spree.stock_transfer_mark_ready_workflow)
          end

          # PATCH /api/v3/admin/stock_transfers/:id/mark_in_transit
          def mark_in_transit
            run_transition(Spree.stock_transfer_mark_in_transit_workflow, force: params[:force].to_b)
          end

          # PATCH /api/v3/admin/stock_transfers/:id/receive
          def receive
            run_transition(Spree.stock_transfer_receive_workflow,
                           items: items_for_receive([:id, :quantity_received, :discrepancy_reason]),
                           received_by: try_spree_current_user)
          end

          # PATCH /api/v3/admin/stock_transfers/:id/cancel
          def cancel
            run_transition(Spree.stock_transfer_cancel_workflow,
                           on_in_transit: params[:on_in_transit],
                           reason: params[:reason],
                           canceler: try_spree_current_user)
          end

          protected

          def model_class
            Spree::StockTransfer
          end

          def serializer_class
            Spree.api.admin_stock_transfer_serializer
          end

          def collection_includes
            [:source_location, :destination_location, { items: :variant }]
          end

          def create_workflow
            Spree.stock_transfer_create_workflow
          end

          def update_workflow
            Spree.stock_transfer_update_workflow
          end

          def workflow_record_key
            :stock_transfer
          end

          def create_workflow_arguments
            {
              store: current_store,
              source_location: stock_location_from(:source_location_id),
              destination_location: stock_location_from(:destination_location_id),
              items: items_from_params(:quantity_shipped) || [],
              reference: params[:reference],
              notes: params[:notes],
              created_by: try_spree_current_user
            }
          end

          def update_workflow_arguments
            {
              stock_transfer: @resource,
              attributes: editable_attributes,
              items: items_from_params(:quantity_shipped)
            }
          end

          # Only what mass assignment may safely carry. The two warehouses are
          # resolved through the store instead, since an id the payload names
          # has to be proved to belong here.
          def resource_permitted_attributes
            [:reference, :notes, { metadata: {} }]
          end

          # A transfer's status transitions are its own actions, so `update`
          # only ever edits the document — and its two ends are objects the
          # store handed us, never ids the payload asserted.
          def editable_attributes
            attributes = permitted_params.to_h.symbolize_keys
            attributes[:source_location] = stock_location_from(:source_location_id) if params.key?(:source_location_id)
            if params.key?(:destination_location_id)
              attributes[:destination_location] = stock_location_from(:destination_location_id)
            end
            attributes
          end

          # The listing and the detail page both read a transfer's totals off
          # its lines.
          def scope_includes
            [{ items: :variant }]
          end
        end
      end
    end
  end
end
