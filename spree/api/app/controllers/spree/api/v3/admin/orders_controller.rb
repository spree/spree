module Spree
  module Api
    module V3
      module Admin
        class OrdersController < ResourceController
          include Spree::Api::V3::OrderLock

          scoped_resource :orders

          # The order accepts a `po_document_signed_id` and streams it back.
          include ActiveStorage::SetCurrent

          ADDRESS = Spree::Api::V3::RequestSchema.shape('AddressInputParams') do |schema|
            schema.include_attributes Spree::Api::V3::Admin::AddressRequestSchema
          end

          request_params :order do |body|
            body.external_references
            body.attribute :email, :string, example: 'customer@example.com'
            body.attribute :customer_id, :id
            body.attribute :use_customer_default_address, :boolean,
              only: :create,
              description: "Copies the saved default billing and shipping addresses onto the order. An order for a company takes that company's defaults, inherited from its parent nodes when it holds none of its own; otherwise it takes the customer's."
            body.attribute :currency, :currency, example: 'USD'
            body.attribute :market_id, :id
            body.attribute :channel_id, :id, description: 'Defaults to the store primary channel when omitted.'
            body.attribute :locale, :locale, example: 'en-US'
            body.attribute :customer_note, :string, description: 'Public, customer-visible note.'
            body.attribute :internal_note, :string,
              description: 'Staff-only note. Rich text HTML; reads come back as this plus `internal_note_html`.'
            body.attribute :po_number, :string,
              description: "The buyer's own purchase-order reference. Searchable alongside the order number, and rendered on every order-facing document."
            body.attribute :po_document_signed_id, :string,
              nullable: true,
              description: "The `signed_id` of the buyer's purchase order, from `files.upload()` with `visibility: 'private'`. Null removes the document the order carries."
            body.attribute :shipping_address_id, :id,
              only: :create,
              description: "An existing address from the customer's address book, or from the address book of the company the order is for."
            body.attribute :billing_address_id, :id,
              only: :create,
              description: "An existing address from the customer's address book, or from the address book of the company the order is for."
            body.attribute :preferred_stock_location_id, :id,
              description: "Stock location to prefer for fulfillment. Order Routing's built-in preferred-location rule ranks it first; routing falls back to the next rule when the location can't cover the cart."
            body.attribute :company_id, :id,
              nullable: true,
              description: "Makes the order a company purchase, with that company's catalog prices and tax treatment. Null makes a draft a plain customer order again."
            body.attribute :coupon_code, :string,
              only: :create,
              description: 'Applied non-fatally: an invalid code does not block creation.'
            body.attribute :metadata, :hash
            body.attribute :tags, :array, of: :string
            body.attribute :shipping_address, :object, shape: ADDRESS
            body.attribute :billing_address, :object, shape: ADDRESS
            body.attribute :items, :array,
              description: 'Line items to upsert, keyed by variant. An entry sets that variant\'s quantity, creating the line item when the order has none; `quantity: 0` removes it. Variants you do not send are left alone.' do |item|
              item.attribute :variant_id, :id, required: true
              item.attribute :quantity, :integer, example: 1
              item.attribute :price, :decimal,
                nullable: true,
                description: "Negotiated unit price; stamps `price_source: 'manual'`. Null reverts the line to catalog pricing. Draft orders only."
              item.attribute :metadata, :hash
            end
          end

          request_params 'OrderCompleteParams', action: :complete do |body|
            body.attribute :payment_pending, :boolean
            body.attribute :notify_customer, :boolean,
              description: 'Send the order confirmation email after completion.'
          end

          request_params 'OrderCancelParams', action: :cancel do |body|
            body.attribute :cancel_reason_id, :id,
              description: "Why the order was canceled: the id of one of the store's cancellation reasons."
            body.attribute :cancel_note, :string, description: 'Staff-facing note about the cancellation.'
            body.attribute :refund_payments, :boolean,
              description: "Whether this order's share of a payment shared across a split checkout is handed back."
            body.attribute :refund_amount, :decimal,
              description: 'How much of that share to return. Defaults to all of it; refused on an order whose payment is not shared.'
            body.attribute :notify_customer, :boolean,
              description: 'Send the order cancellation email after canceling.'
          end

          skip_before_action :set_resource, only: [:index, :create]
          before_action :set_resource, only: [:show, :update, :destroy, :complete, :cancel, :approve, :resend_confirmation, :resend_digital_links, :po_document]

          # POST /api/v3/admin/orders
          def create
            authorize!(:create, Spree::Order)

            result = Spree.order_create_service.call(
              store: current_store,
              customer: resolve_customer,
              created_by: current_actor,
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
          #
          # An order holding several sellers' goods divides into one order per
          # seller, so the group is what comes back — the orders it produced
          # are nested inside it.
          def complete
            with_order_lock do
              result = Spree.order_complete_workflow.call(
                order: @resource,
                payment_pending: params[:payment_pending].to_b,
                notify_customer: ActiveModel::Type::Boolean.new.cast(params[:notify_customer])
              )

              if result.success?
                render json: serialize_completion(result.value)
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
                canceler: current_actor,
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
              @resource.approved_by(current_actor)
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
                message: I18n.t('spree.po_document_missing'),
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

          # Completion answers with whatever it produced: one order, or the
          # group a multi-seller order divided into.
          #
          # The group is rendered whole rather than through `filter_fields`: a
          # `fields` list names an order's attributes, and narrowing a group by
          # it can drop the very keys that say it is one.
          def serialize_completion(record)
            return serialize_resource(record.reload) unless record.is_a?(Spree::OrderGroup)

            Spree.api.admin_order_group_serializer.new(completed_group(record), params: serializer_params).to_h
          end

          # Every child is rendered in full, so its associations are loaded once
          # here rather than per order.
          def completed_group(group)
            Spree::OrderGroup.includes(
              :customer, :ship_address, :bill_address,
              { payments: %i[payment_method source] },
              { orders: [:seller, :market, :gift_card, :customer, { line_items: { variant: :prices } }] }
            ).find(group.id)
          end

          # Override scope — Order uses SingleStoreResource (for_store).
          # Variant prices and each line's price list are named here rather
          # than via scope_includes, which this override bypasses; the
          # serializer reads both per row.
          def scope
            base = current_store.orders.accessible_by(current_ability, :show).
                   includes(line_items: [{ variant: :prices }, { price_list: :catalog }]).
                   preload_associations_lazily

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
          # comparison); without it each line costs its own price query. Each
          # line's price list and its catalog are named for the same reason —
          # stated rather than left to ar_lazy_preload, which happens to cover
          # them today.
          def collection_includes
            # `market` is the withdrawal deadline's other input. Fulfillments
            # are loaded with their selected rate because the freight summary
            # reads it — otherwise a page of orders costs a query per
            # fulfillment for a field that is nil on every parcel order.
            [:customer, :channel, :seller, :external_references, :cancel_reason,
             :market, { fulfillments: %i[selected_delivery_rate external_references] },
             { line_items: [:external_references, { variant: :prices }, { price_list: :catalog }] },
             { po_document_attachment: :blob }]
          end

          # Read through the store's own vocabulary, so a reason belonging to
          # another store is a 404 rather than a silent mislabel.
          def cancel_reason
            id = params[:cancel_reason_id].presence
            return if id.nil?

            current_store.order_cancellation_reasons.find_by_prefix_id!(id)
          end

          private

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
            resolve_company_param(normalize_params(params.permit(*request_params_schema.permit_list(:create))))
          end

          # Named rather than read from the action, since an upsert reaches
          # update from the create action.
          def order_update_params
            resolve_company_param(normalize_params(params.permit(*request_params_schema.permit_list(:update))))
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
        end
      end
    end
  end
end
