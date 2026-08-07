module Spree
  module Api
    module V3
      module Store
        module Orders
          # Customer self-service claims — reporting a damaged, missing or
          # wrong item. Approving, denying and resolving are the merchant's,
          # through the Admin API.
          #
          # Whether a customer may file a claim is store policy and belongs in
          # a `claims.create.validate` hook rather than here.
          class ClaimsController < Store::ResourceController
            def create
              result = Spree.claim_create_workflow.call(
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
              Spree::Claim
            end

            def serializer_class
              Spree.api.claim_serializer
            end

            def scope
              @parent.claims.order(created_at: :desc)
            end

            def collection_includes
              [{ claim_line_items: :variant }]
            end

            def set_parent
              cart_pk = Spree::Cart.decode_own_prefixed_id(params[:order_id])
              @parent = if cart_pk
                          order_scope.find_by!(cart_id: cart_pk)
                        else
                          order_scope.find_by_prefix_id!(params[:order_id])
                        end
              authorize!(:show, @parent, order_token)
            end

            # Authorization is the parent order's — see the returns
            # controller for why a second record-level check is wrong here.
            def set_resource
              @resource = find_resource
            end

            def order_scope
              base = current_store.orders.complete

              if current_user.present?
                base.where(customer: current_user)
              elsif order_token.present?
                base.where(token: order_token)
              else
                base.none
              end
            end

            def create_params
              @create_params ||= params.permit(:memo, :reason_id,
                                               items: [:line_item_id, :quantity, :description])
            end

            private

            def items_for_create
              Array(create_params[:items]).map do |item|
                {
                  line_item: @parent.line_items.find_by_prefix_id!(item[:line_item_id]),
                  quantity: item[:quantity].to_i,
                  description: item[:description]
                }
              end
            end

            # Read through the store so a reason belonging to another store
            # 404s rather than being silently attached.
            def reason_for_create
              return nil if create_params[:reason_id].blank?

              current_store.claim_reasons.find_by_prefix_id!(create_params[:reason_id])
            end
          end
        end
      end
    end
  end
end
