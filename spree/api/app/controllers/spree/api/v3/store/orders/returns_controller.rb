module Spree
  module Api
    module V3
      module Store
        module Orders
          # Customer self-service returns. Whether a customer may open one at
          # all is store policy, and belongs in a `returns.create.validate`
          # hook rather than here; the order payload previews the same
          # verdict as `returns_eligibility`.
          class ReturnsController < Store::ResourceController
            include Spree::Api::V3::Store::CustomerPostSale
            include Spree::Api::V3::Store::CustomerWithdrawal
            include Spree::Api::V3::StreamsShippingLabel

            # Re-declaring the filter replaces the inherited options, so the
            # standard actions are listed alongside the member actions.
            before_action :set_resource, only: [:show, :update, :destroy, :label, :cancel]

            request_params 'CreateReturnParams', action: :create do |body|
              body.attribute :items, :array, required: true do |item|
                item.attribute :fulfillment_item_id, :id, required: true, description: 'The shipped unit coming back.'
                item.attribute :quantity, :integer, required: true
              end
              body.attribute :reason_id, :id, description: "One of the store's return reasons."
              body.attribute :memo, :string
            end

            # GET /api/v3/store/orders/:order_id/returns/:id/label
            #
            # The customer's return label, streamed to whoever owns the order.
            # The label row itself is never serialized to the storefront —
            # its cost and provider ids are merchant data — only the file.
            def label
              shipping_label = @resource.active_shipping_label
              return head :not_found if shipping_label.nil?

              stream_shipping_label(shipping_label) { head :not_found }
            end

            def create
              result = Spree.return_create_workflow.call(
                order: @parent,
                items: items_for_create,
                reason: reason_for_create,
                memo: create_params[:memo]
              )

              render_result(result, status: :created)
            end

            protected

            def model_class
              Spree::Return
            end

            def serializer_class
              Spree.api.return_serializer
            end

            def scope
              @parent.returns.order(created_at: :desc)
            end

            def collection_includes
              [{ return_line_items: :variant }, :shipping_labels, :deliveries]
            end

            def read_actions
              %w[index show label]
            end

            def cancel_workflow
              Spree.return_cancel_workflow
            end

            def workflow_record_key
              :return_record
            end

            private

            def items_for_create
              Array(create_params[:items]).map do |item|
                { fulfillment_item: fulfillment_item_for(item[:fulfillment_item_id]), quantity: item[:quantity].to_i }
              end
            end
          end
        end
      end
    end
  end
end
