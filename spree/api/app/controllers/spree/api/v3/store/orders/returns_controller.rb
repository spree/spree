module Spree
  module Api
    module V3
      module Store
        module Orders
          # Customer self-service returns. A customer can open a return and
          # see the ones they opened; everything after that — approving,
          # receiving, refunding — is the merchant's to do through the Admin
          # API.
          #
          # Whether a customer may open a return at all is store policy, and
          # belongs in a `returns.create.validate` hook rather than here.
          class ReturnsController < Store::ResourceController
            # Re-declaring the filter replaces the inherited options, so the
            # standard actions are listed alongside the label download.
            before_action :set_resource, only: [:show, :update, :destroy, :label]

            # GET /api/v3/store/orders/:order_id/returns/:id/label
            #
            # The customer's return label, streamed to whoever owns the order.
            # The label row itself is never serialized to the storefront —
            # its cost and provider ids are merchant data — only the file.
            def label
              shipping_label = @resource.active_shipping_label
              return head :not_found if shipping_label.nil?

              if shipping_label.file.attached?
                send_data(
                  shipping_label.file.download,
                  filename: shipping_label.download_filename,
                  type: shipping_label.file.content_type || 'application/octet-stream',
                  disposition: 'attachment'
                )
              elsif shipping_label.file_pending?
                redirect_to shipping_label.file_url, allow_other_host: true
              else
                head :not_found
              end
            end

            def create
              result = Spree.return_create_workflow.call(
                order: @parent,
                items: items_for_create,
                reason: reason_for_create,
                memo: create_params[:memo]
              )

              if result.success?
                render json: serialize_resource(result.value), status: :created
              else
                render_result_error(result)
              end
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
              [{ return_line_items: :variant }]
            end

            # Authorization is the parent order's: set_parent already proved
            # this customer owns it (by JWT or guest token), and the scope is
            # that order's own returns.
            def set_resource
              @resource = find_resource
            end

            def read_actions
              %w[index show label]
            end

            # The order is the customer's own — by JWT or by guest token,
            # mirroring Store::OrdersController.
            def set_parent
              cart_pk = Spree::Cart.decode_own_prefixed_id(params[:order_id])
              @parent = if cart_pk
                          order_scope.find_by!(cart_id: cart_pk)
                        else
                          order_scope.find_by_prefix_id!(params[:order_id])
                        end
            end

            def order_scope
              storefront_access_policy.scope(current_store.orders.complete, token: order_token)
            end

            def create_params
              @create_params ||= params.permit(:memo, :reason_id, items: [:fulfillment_item_id, :quantity])
            end

            private

            def items_for_create
              Array(create_params[:items]).map do |item|
                {
                  fulfillment_item: @parent.fulfillment_items.find_by_prefix_id!(item[:fulfillment_item_id]),
                  quantity: item[:quantity].to_i
                }
              end
            end

            def reason_for_create
              return nil if create_params[:reason_id].blank?

              current_store.return_reasons.find_by_prefix_id!(create_params[:reason_id])
            end
          end
        end
      end
    end
  end
end
