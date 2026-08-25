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
              customer: resolve_user,
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
                payment_pending: params[:payment_pending].to_b,
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
              result = Spree.order_cancel_workflow.call(
                order: @resource,
                canceler: try_spree_current_user,
                notify_customer: params[:notify_customer].to_b
              )

              if result.success?
                render json: serialize_resource(@resource.reload)
              else
                render_service_error(@resource.errors.presence || result.error)
              end
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
            @resource.publish_event('order.resend_confirmation_email')
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
            base = current_store.orders.accessible_by(current_ability, :show).preload_associations_lazily

            # Transient completion drafts (status draft + cart_id set) belong
            # to in-flight checkouts, never to the admin. Admin drafts are the
            # cart-less ones.
            base.where(cart_id: nil).or(base.where.not(status: 'draft'))
          end

          # Through find_resource, not find_by_prefix_id! directly, so the
          # external:<system>:<id> addressing the concern provides reaches
          # orders — an ERP that pushed its order number wants to read the
          # order back by it.
          def set_resource
            @resource = find_resource
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

          # seller is preloaded because its id is read on every row and an
          # expanded list renders the whole profile; order_group is not, since
          # only its id is reported and that comes off the order's own column.
          def collection_includes
            [:line_items, :customer, :channel, :seller, :external_references]
          end

          private

          def resolve_user
            customer_param = params[:customer_id].presence || params[:user_id].presence
            return unless customer_param

            Spree.customer_class.
              accessible_by(current_ability, :show).
              find_by_prefix_id!(customer_param)
          end

          # An upsert arrives on the create action, so addresses come in under
          # the create names. Translate them to the ones update accepts, or a
          # replayed feed row would silently lose the address it sent.
          def normalize_upsert_params!
            # update runs under with_order_lock, which reads @order — normally
            # set by set_resource, which the create path never runs.
            @order = @resource
          end

          def order_create_params
            normalize_params(
              params.permit(
                :email, :customer_id, :user_id, :use_customer_default_address,
                :currency, :market_id, :channel_id, :locale,
                :customer_note, :internal_note,
                :shipping_address_id, :billing_address_id,
                :preferred_stock_location_id,
                :coupon_code,
                metadata: {},
                tags: [],
                shipping_address: address_permitted_keys,
                billing_address: address_permitted_keys,
                items: item_permitted_keys
              )
            )
          end

          def order_update_params
            permitted = normalize_params(
              params.permit(
                :email, :customer_id, :user_id,
                :customer_note, :internal_note,
                :currency, :locale, :market_id, :channel_id,
                :preferred_stock_location_id, :company_id,
                metadata: {},
                tags: [],
                shipping_address: address_permitted_keys,
                billing_address: address_permitted_keys,
                items: item_permitted_keys
              )
            )
            resolve_company_param(permitted)
          end

          # An incidental lookup like any other: resolved through the store so
          # another tenant's node 404s instead of surfacing as a validation
          # error (which would confirm the id exists). Reads the raw param —
          # normalize_params has already decoded the prefixed id.
          def resolve_company_param(permitted)
            return permitted unless permitted.key?(:company_id)

            permitted[:company_id] =
              if params[:company_id].present?
                current_store.companies.find_by_prefix_id!(params[:company_id]).id
              else
                nil
              end
            permitted
          end

          def address_permitted_keys
            [
              :firstname, :lastname, :first_name, :last_name,
              :address1, :address2, :city,
              :country_code, :state_code,
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
