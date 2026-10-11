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

          # The warehouses and lines are read from the raw params and resolved
          # through the store (see ReceivableActions), so only the document's
          # own fields are permitted.
          request_params :stock_transfer do
            id :source_location_id, :destination_location_id, required: :create, permit: false, example: 'sloc_1234567890'
            string :reference, nullable: true, description: "The merchant's own label for the trip. `null` clears it."
            string :notes, nullable: true
            object :items, array: true, permit: false, as: 'StockTransferItemParams',
                           description: 'A draft may open empty and gain lines as the merchant packs. Sending the list replaces whatever the draft currently holds.' do
              id :variant_id, required: true, example: 'variant_1234567890'
              integer :quantity_shipped, required: true, example: 10
            end
            object :metadata, nullable: true, only: :update
          end

          request_params 'StockTransferMarkInTransitParams', action: :mark_in_transit do
            boolean :force, description: 'Ship even if it drives the source below zero.'
          end

          request_params 'ReceivableCloseParams', action: :close do
            string :reason, nullable: true, description: 'Why the balance is not coming.'
          end

          request_params 'StockTransferCancelParams', action: :cancel do
            string :on_in_transit, enum: %w[restock write_off],
                                   description: 'Required once the units have left the source: either they come back (`restock`) or they are written off as lost (`write_off`).'
            string :reason, nullable: true, description: 'Recorded against the written-off lines.'
          end

          # The base registers this for show/update/destroy; a second
          # `before_action :set_resource` replaces that registration rather than
          # adding to it, so those three are listed again here.
          before_action :set_resource, only: [:show, :update, :destroy, :mark_ready, :mark_in_transit, :mark_draft, :close, :cancel]

          # DELETE /api/v3/admin/stock_transfers/:id
          #
          # A draft is the only transfer a merchant may throw away: past that
          # it describes a box that physically exists, which is cancelled
          # rather than deleted.
          #
          # Really deleted, not stamped. Soft deletion exists for the upgrade
          # task's converted receives, whose numbers have to stay findable; a
          # draft nobody sent has nothing to preserve, and `destroy` would
          # hard-delete its lines regardless (they are not paranoid), leaving a
          # soft-deleted row that could never be restored intact.
          def destroy
            unless @resource.draft?
              return render_error(
                code: 'invalid_status',
                message: I18n.t('spree.stock_transfer.errors.only_draft_can_be_deleted'),
                status: :unprocessable_content
              )
            end

            authorize_resource!(@resource, :destroy)
            @resource.really_destroy!
            head :no_content
          end

          # PATCH /api/v3/admin/stock_transfers/:id/mark_ready
          def mark_ready
            result = Spree.stock_transfer_mark_ready_workflow.call(stock_transfer: @resource)
            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value)
          end

          # PATCH /api/v3/admin/stock_transfers/:id/mark_in_transit
          def mark_in_transit
            result = Spree.stock_transfer_mark_in_transit_workflow.call(
              stock_transfer: @resource,
              force: params[:force].to_b
            )
            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value)
          end

          # PATCH /api/v3/admin/stock_transfers/:id/mark_draft
          def mark_draft
            result = Spree.stock_transfer_mark_draft_workflow.call(stock_transfer: @resource)
            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value)
          end

          # PATCH /api/v3/admin/stock_transfers/:id/close
          #
          # Deliveries are recorded through the nested stock receipts; this is
          # for units that left the source and are not going to turn up.
          def close
            result = Spree.stock_transfer_close_workflow.call(stock_transfer: @resource, reason: params[:reason])
            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value)
          end

          # PATCH /api/v3/admin/stock_transfers/:id/cancel
          def cancel
            result = Spree.stock_transfer_cancel_workflow.call(
              stock_transfer: @resource,
              on_in_transit: params[:on_in_transit],
              reason: params[:reason],
              canceler: try_spree_current_user
            )
            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value)
          end

          protected

          def model_class
            Spree::StockTransfer
          end

          def serializer_class
            Spree.api.admin_stock_transfer_serializer
          end

          def collection_includes
            [:source_location, :destination_location, line_includes]
          end

          def create_workflow
            Spree.stock_transfer_create_workflow
          end

          def update_workflow
            Spree.stock_transfer_update_workflow
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
            [line_includes]
          end
        end
      end
    end
  end
end
