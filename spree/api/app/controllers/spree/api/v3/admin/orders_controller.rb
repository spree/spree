module Spree
  module Api
    module V3
      module Admin
        class OrdersController < ResourceController
          include Spree::Api::V3::OrderLock

          skip_before_action :set_resource, only: [:index, :create]
          before_action :set_resource, only: [:show, :update, :destroy, :next, :advance, :complete, :cancel, :approve, :resume, :resend_confirmation]

          # POST /api/v3/admin/orders
          def create
            authorize!(:create, Spree::Order)

            result = Spree.cart_create_service.call(
              user: resolve_user,
              store: current_store,
              currency: params[:currency] || current_store.default_currency,
              order_params: order_create_params
            )

            if result.success?
              @resource = result.value
              render json: serialize_resource(@resource), status: :created
            else
              render_service_error(result.error)
            end
          end

          # PATCH /api/v3/admin/orders/:id
          def update
            with_order_lock do
              result = Spree.order_update_service.call(
                order: @resource,
                params: order_update_params
              )

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_result_error(result)
              end
            end
          end

          # DELETE /api/v3/admin/orders/:id
          # CanCanCan restricts destroy to orders where can_be_deleted? is true
          def destroy
            @resource.destroy
            head :no_content
          end

          # PATCH /api/v3/admin/orders/:id/next
          def next
            with_order_lock do
              result = Spree.checkout_next_service.call(order: @resource)

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_service_error(result.error, code: ERROR_CODES[:order_cannot_transition])
              end
            end
          end

          # PATCH /api/v3/admin/orders/:id/advance
          def advance
            with_order_lock do
              result = Spree.checkout_advance_service.call(order: @resource)

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_service_error(result.error, code: ERROR_CODES[:order_cannot_transition])
              end
            end
          end

          # PATCH /api/v3/admin/orders/:id/complete
          def complete
            with_order_lock do
              result = Spree.checkout_complete_service.call(order: @resource)

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_service_error(result.error, code: ERROR_CODES[:order_already_completed])
              end
            end
          end

          # PATCH /api/v3/admin/orders/:id/cancel
          def cancel
            with_order_lock do
              @resource.canceled_by(try_spree_current_user)
              render json: serialize_resource(@resource.reload)
            end
          end

          # PATCH /api/v3/admin/orders/:id/approve
          def approve
            with_order_lock do
              @resource.approved_by(try_spree_current_user)
              render json: serialize_resource(@resource.reload)
            end
          end

          # PATCH /api/v3/admin/orders/:id/resume
          def resume
            with_order_lock do
              @resource.resume!
              render json: serialize_resource(@resource.reload)
            end
          end

          # POST /api/v3/admin/orders/:id/resend_confirmation
          def resend_confirmation
            @resource.publish_event('order.completed')
            render json: serialize_resource(@resource)
          end

          protected

          def model_class
            Spree::Order
          end

          def serializer_class
            Spree.api.admin_order_serializer
          end

          # Override scope — Order uses SingleStoreResource (for_store)
          def scope
            current_store.orders.accessible_by(current_ability, :show).preload_associations_lazily
          end

          def set_resource
            @resource = scope.find_by_prefix_id!(params[:id])
            @order = @resource # needed for OrderLock
            authorize_resource!(@resource)
          end

          # Map state transition actions to :update permission
          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            mapped_action = case action
                            when :next, :advance, :complete, :cancel, :approve, :resume, :resend_confirmation
                              :update
                            else
                              action
                            end
            authorize!(mapped_action, resource)
          end

          def collection_includes
            [:line_items, :user]
          end

          private

          def resolve_user
            return unless params[:user_id].present?

            Spree.user_class.find_by_param!(params[:user_id])
          end

          def order_create_params
            {
              email: params[:email],
              channel: params[:channel],
              internal_note: params[:internal_note]
            }.compact
          end

          def order_update_params
            params.permit(
              *Spree::PermittedAttributes.checkout_attributes,
              ship_address: Spree::PermittedAttributes.address_attributes,
              bill_address: Spree::PermittedAttributes.address_attributes,
              line_items: Spree::PermittedAttributes.line_item_attributes
            )
          end
        end
      end
    end
  end
end
