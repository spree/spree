module Spree
  module Api
    module V3
      module Admin
        class OrdersController < ResourceController
          include Spree::Api::V3::OrderLock

          scoped_resource :orders

          skip_before_action :set_resource, only: [:index, :create]
          before_action :set_resource, only: [:show, :update, :destroy, :complete, :cancel, :approve, :resume, :resend_confirmation]

          # POST /api/v3/admin/orders
          def create
            authorize!(:create, Spree::Order)

            result = Spree.order_create_service.call(
              store: current_store,
              user: resolve_user,
              params: order_create_params
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
                render json: serialize_resource(result.value)
              else
                render_validation_error(@resource.errors.presence || result.error)
              end
            end
          end

          # PATCH /api/v3/admin/orders/:id/complete
          def complete
            with_order_lock do
              result = Spree.order_complete_service.call(
                order: @resource,
                payment_pending: ActiveModel::Type::Boolean.new.cast(params[:payment_pending]),
                notify_customer: ActiveModel::Type::Boolean.new.cast(params[:notify_customer])
              )

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_service_error(@resource.errors.presence || result.error, code: ERROR_CODES[:order_cannot_complete])
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
                            when :complete, :cancel, :approve, :resume, :resend_confirmation
                              :update
                            else
                              action
                            end
            authorize!(mapped_action, resource)
          end

          def collection_includes
            [:line_items, :user, :rich_text_internal_note]
          end

          private

          def resolve_user
            customer_param = params[:customer_id].presence || params[:user_id].presence
            return unless customer_param

            Spree.user_class.find_by_param!(customer_param)
          end

          def order_create_params
            params.permit(
              :email, :customer_id, :user_id, :use_customer_default_address,
              :currency, :market_id, :locale,
              :customer_note, :internal_note,
              :shipping_address_id, :billing_address_id,
              :coupon_code,
              metadata: {},
              tags: [],
              shipping_address: address_permitted_keys,
              billing_address: address_permitted_keys,
              items: item_permitted_keys
            )
          end

          def order_update_params
            params.permit(
              :email, :customer_id, :user_id,
              :customer_note, :internal_note,
              :currency, :locale, :market_id,
              metadata: {},
              tags: [],
              ship_address: address_permitted_keys,
              bill_address: address_permitted_keys,
              items: item_permitted_keys
            )
          end

          def address_permitted_keys
            [
              :firstname, :lastname, :first_name, :last_name,
              :address1, :address2, :city,
              :country_iso, :state_abbr, :country_id, :state_id,
              :zipcode, :postal_code, :phone, :alternative_phone,
              :state_name, :company, :label
            ]
          end

          def item_permitted_keys
            [:variant_id, :quantity, { metadata: {} }]
          end
        end
      end
    end
  end
end
