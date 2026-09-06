module Spree
  module Api
    module V3
      module Admin
        class OrdersController < ResourceController
          include Spree::Api::V3::OrderLock

          scoped_resource :orders

          # The order accepts a `po_document` signed blob id and streams it back.
          include ActiveStorage::SetCurrent

          # A tampered signed id would otherwise surface as a 500.
          rescue_from ActiveSupport::MessageVerifier::InvalidSignature, with: :render_invalid_po_document

          skip_before_action :set_resource, only: [:index, :create]
          before_action :set_resource, only: [:show, :update, :destroy, :complete, :cancel, :approve, :resend_confirmation, :resend_digital_links, :po_document]

          # POST /api/v3/admin/orders
          def create
            authorize!(:create, Spree::Order)

            result = Spree.order_create_service.call(
              store: current_store,
              customer: resolve_customer,
              created_by: try_spree_current_user,
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
                reason: cancel_reason,
                note: params[:cancel_note].presence,
                refund_payments: params[:refund_payments].to_b,
                refund_amount: params[:refund_amount].presence,
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

          # POST /api/v3/admin/orders/:id/resend_confirmation
          def resend_confirmation
            @resource.publish_event('order.resend_confirmation_email')
            render json: serialize_resource(@resource)
          end

          # POST /api/v3/admin/orders/:id/resend_digital_links
          def resend_digital_links
            @resource.publish_event('order.resend_digital_links_email')
            render json: serialize_resource(@resource)
          end

          # GET /api/v3/admin/orders/:id/po_document
          #
          # The buyer's purchase order, streamed rather than redirected so the
          # document is never reachable without admin credentials.
          def po_document
            unless @resource.po_document.attached?
              return render_error(
                code: ERROR_CODES[:validation_error],
                message: Spree.t(:po_document_missing),
                status: :unprocessable_content
              )
            end

            send_data(
              @resource.po_document.download,
              filename: @resource.po_document.filename.to_s,
              type: @resource.po_document.content_type || 'application/octet-stream',
              disposition: 'attachment'
            )
          end

          protected

          # Fetching the document is a read of the order, so it takes the read
          # scope rather than being classed as a write for not being index or
          # show.
          READ_ACTIONS = %w[index show po_document].freeze

          def read_actions
            READ_ACTIONS
          end

          def model_class
            Spree::Order
          end

          def serializer_class
            Spree.api.admin_order_serializer
          end

          # Override scope — Order uses SingleStoreResource (for_store).
          # Variant prices are preloaded here rather than via scope_includes,
          # which this override bypasses; the serializer reads them per row.
          def scope
            base = current_store.orders.accessible_by(current_ability, :show).
                   includes(line_items: { variant: :prices }).preload_associations_lazily

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
                            when :complete, :cancel, :approve, :resend_confirmation, :resend_digital_links
                              :update
                            when :po_document
                              :show
                            else
                              action
                            end
            authorize!(mapped_action, resource)
          end

          # seller is preloaded because its id is read on every row and an
          # expanded list renders the whole profile; order_group is not, since
          # only its id is reported and that comes off the order's own column.
          # Variant prices ride along because the admin line-item serializer
          # reads the base catalog price for every row (the negotiated-price
          # comparison); without it each line costs its own price query.
          def collection_includes
            # `market` and `fulfillments` are the withdrawal deadline's inputs,
            # which the serializer emits on every row.
            [:customer, :channel, :seller, :external_references, :cancel_reason,
             :market, :fulfillments,
             { line_items: { variant: :prices } }, { po_document_attachment: :blob }]
          end

          # Read through the store's own vocabulary, so a reason belonging to
          # another store is a 404 rather than a silent mislabel.
          def cancel_reason
            id = params[:cancel_reason_id].presence
            return if id.nil?

            current_store.order_cancellation_reasons.find_by_prefix_id!(id)
          end

          private

          def render_invalid_po_document
            render_error(
              code: ERROR_CODES[:validation_error],
              message: Spree.t(:po_document_invalid_signed_id),
              status: :unprocessable_content
            )
          end

          def resolve_customer
            customer_param = params[:customer_id].presence
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
            permitted = normalize_params(
              params.permit(
                :email, :customer_id, :use_customer_default_address,
                :currency, :market_id, :channel_id, :locale,
                :customer_note, :internal_note,
                # The buyer's own purchase-order reference, and the signed blob
                # id of the document behind it — a PO arriving by email and
                # keyed in is the draft-order flow plus these two fields.
                :po_number, :po_document,
                :shipping_address_id, :billing_address_id,
                :preferred_stock_location_id, :company_id,
                :coupon_code,
                metadata: {},
                tags: [],
                shipping_address: address_permitted_keys,
                billing_address: address_permitted_keys,
                items: item_permitted_keys
              )
            )
            resolve_company_param(permitted)
          end

          def order_update_params
            permitted = normalize_params(
              params.permit(
                :email, :customer_id,
                :customer_note, :internal_note,
                :po_number, :po_document,
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
            [:variant_id, :quantity, :price, { metadata: {} }]
          end
        end
      end
    end
  end
end
