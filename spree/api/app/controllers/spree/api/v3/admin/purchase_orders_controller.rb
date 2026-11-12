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

          # The supplier, the warehouse and the lines are read from the raw
          # params and resolved through the store (see ReceivableActions), so
          # only the document's own fields are permitted.
          request_params :purchase_order do |body|
            body.attribute :supplier_id, :id, required: true, on: :create, permit: false, example: 'sup_1234567890'
            body.attribute :destination_location_id, :id,
              required: true, on: :create,
              permit: false,
              example: 'sloc_1234567890'
            body.attribute :currency, :currency,
              nullable: true,
              example: 'USD',
              description: "Defaults to the store's currency; set it for a foreign-currency order."
            body.attribute :expected_at, :date,
              nullable: true,
              example: '2026-10-01',
              description: 'The day the supplier promised. `null` clears it.'
            body.attribute :cancel_by, :date,
              nullable: true,
              description: 'The day after which the goods are no longer wanted. `null` clears it.'
            body.attribute :reference, :string,
              nullable: true,
              description: "The supplier's own order number. `null` clears it."
            body.attribute :notes, :string, nullable: true
            body.attribute :items, :array,
              permit: false,
              as: 'PurchaseOrderItemParams',
              description: 'Sending the list replaces whatever the order currently holds.' do |item|
              item.attribute :variant_id, :id, required: true, example: 'variant_1234567890'
              item.attribute :quantity_ordered, :integer, required: true, example: 100
              item.attribute :unit_cost, :decimal,
                required: true,
                example: '12.50',
                description: 'What the merchant agreed to pay per unit.'
            end
            body.attribute :metadata, :hash, nullable: true
          end

          request_params 'ReceivableCloseParams', action: :close do |body|
            body.attribute :reason, :string, nullable: true, description: 'Why the balance is not coming.'
          end

          request_params 'PurchaseOrderCancelParams', action: :cancel do |body|
            body.attribute :reason, :string,
              example: 'Supplier went under',
              description: "Appended to the order's notes."
          end

          # The base registers this for show/update/destroy; a second
          # `before_action :set_resource` replaces that registration rather than
          # adding to it, so those three are listed again here.
          before_action :set_resource, only: [:show, :update, :destroy, :mark_ordered, :mark_draft, :close, :cancel]

          # DELETE /api/v3/admin/purchase_orders/:id
          #
          # Only a draft. Once the order has gone to the supplier it is a
          # matter of record between two businesses, and is cancelled rather
          # than deleted.
          def destroy
            return super if @resource.draft?

            render_error(
              code: 'invalid_status',
              message: I18n.t('spree.purchase_order.errors.only_draft_can_be_deleted'),
              status: :unprocessable_content
            )
          end

          # PATCH /api/v3/admin/purchase_orders/:id/mark_ordered
          def mark_ordered
            result = Spree.purchase_order_mark_ordered_workflow.call(purchase_order: @resource)
            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value)
          end

          # PATCH /api/v3/admin/purchase_orders/:id/receive
          # PATCH /api/v3/admin/purchase_orders/:id/mark_draft
          def mark_draft
            result = Spree.purchase_order_mark_draft_workflow.call(purchase_order: @resource)
            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value)
          end

          # PATCH /api/v3/admin/purchase_orders/:id/close
          #
          # Deliveries are recorded through the nested stock receipts; this is
          # for the balance that is not coming.
          def close
            result = Spree.purchase_order_close_workflow.call(purchase_order: @resource, reason: params[:reason])
            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value)
          end

          # PATCH /api/v3/admin/purchase_orders/:id/cancel
          def cancel
            result = Spree.purchase_order_cancel_workflow.call(
              purchase_order: @resource,
              reason: params[:reason],
              canceler: try_spree_current_user
            )
            return render_result_error(result) unless result.success?

            render json: serialize_resource(result.value)
          end

          protected

          def model_class
            Spree::PurchaseOrder
          end

          def serializer_class
            Spree.api.admin_purchase_order_serializer
          end

          def collection_includes
            [:supplier, :destination_location, line_includes]
          end

          def create_workflow
            Spree.purchase_order_create_workflow
          end

          def update_workflow
            Spree.purchase_order_update_workflow
          end

          def create_workflow_arguments
            {
              store: current_store,
              supplier: supplier_from_params,
              destination_location: stock_location_from(:destination_location_id),
              items: items_from_params(:quantity_ordered, :unit_cost) || [],
              currency: params[:currency],
              expected_at: params[:expected_at],
              cancel_by: params[:cancel_by],
              reference: params[:reference],
              notes: params[:notes],
              metadata: metadata_from_params,
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

          def editable_attributes
            attributes = permitted_params.to_h.symbolize_keys
            attributes[:supplier] = supplier_from_params if params.key?(:supplier_id)
            if params.key?(:destination_location_id)
              attributes[:destination_location] = stock_location_from(:destination_location_id)
            end
            attributes
          end

          def scope_includes
            [line_includes]
          end

          private

          # Merchant data, stored as sent: never through the prefixed-id decoding
          # `permitted_params` applies.
          def metadata_from_params
            params.permit(*declared_permitted_attributes)[:metadata]&.to_h
          end

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
