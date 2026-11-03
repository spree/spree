module Spree
  module Api
    module V3
      module Admin
        module Orders
          # Changes to a placed order (docs/plans/6.1-order-change-substrate.md).
          #
          # A caller that knows the whole change previews it, then creates it
          # with `confirm: true` — one request, all or nothing. Created without
          # `confirm`, the set waits as `requested` for a later confirm or
          # cancel. Drafts are edited directly through the order, never here.
          class OrderChangesController < BaseController
            # A subject of the `orders` catalog resource, like returns.
            scoped_resource :orders

            request_params :order_change do |body|
              body.attribute :actions, :array,
                of: Spree::Api::V3::Admin::OrderChangeActionRequestSchema,
                required: true, on: :create, only: :create, permit: false,
                description: 'The changes, applied in order.'
              body.attribute :confirm, :boolean,
                only: :create, permit: false,
                description: 'Apply the change at once. Omitted or false, it waits as `requested` for a confirm or cancel.'
              body.attribute :metadata, :hash, only: :create
            end

            request_params 'OrderChangePreviewParams', action: :preview do |body|
              body.attribute :actions, :array,
                of: Spree::Api::V3::Admin::OrderChangeActionRequestSchema,
                required: true, permit: false,
                description: 'The changes to preview. Nothing is saved.'
            end

            before_action :set_resource, only: [:show, :confirm, :cancel]

            # POST /api/v3/admin/orders/:order_id/order_changes
            def create
              authorize!(:create, Spree::OrderChange)

              with_order_lock do
                result = Spree.order_change_apply_service.call(
                  order: @order,
                  actions: actions_param,
                  requested_by: current_actor,
                  confirm: ActiveModel::Type::Boolean.new.cast(params[:confirm]) || false,
                  metadata: params.permit(metadata: {})[:metadata].to_h
                )

                render_result(result, status: :created)
              end
            end

            # POST /api/v3/admin/orders/:order_id/order_changes/preview
            def preview
              authorize!(:create, Spree::OrderChange)

              order_change = @order.order_changes.new
              actions_param.each_with_index do |action, position|
                order_change.actions.build(action.merge(position: position))
              end

              invalid = order_change.actions.find(&:invalid?)
              return render_validation_error(invalid.errors) if invalid

              result = Spree.order_change_preview_service.call(order_change: order_change)
              if result.success?
                render json: Spree.api.admin_order_change_preview_serializer.new(result.value, params: serializer_params).to_h
              else
                render_result_error(result)
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/order_changes/:id/confirm
            def confirm
              with_order_lock { render_result(Spree.order_change_confirm_workflow.call(order_change: @resource)) }
            end

            # PATCH /api/v3/admin/orders/:order_id/order_changes/:id/cancel
            def cancel
              render_result(Spree.order_change_cancel_workflow.call(order_change: @resource))
            end

            protected

            def model_class
              Spree::OrderChange
            end

            def serializer_class
              Spree.api.admin_order_change_serializer
            end

            def scope
              @order.order_changes
            end

            def collection_includes
              [:requested_by, :order, :return, :exchange, :claim,
               { actions: [:line_item, :variant, :fulfillment, :delivery_method] }]
            end

            private

            # Every id resolves through this order or this store, so a payload
            # cannot name another order's line or another store's variant —
            # one query per kind of record, however many actions there are.
            def actions_param
              @actions_param ||= begin
                actions = Array(params[:actions]).map { |action| action.permit(:kind, :line_item_id, :variant_id, :quantity) }
                line_items = resolve_ids(@order.line_items.includes(:variant), actions.pluck(:line_item_id))
                variants = resolve_ids(current_store.variants, actions.pluck(:variant_id))

                actions.map do |action|
                  {
                    kind: action[:kind].to_s,
                    line_item: line_items[action[:line_item_id]],
                    variant: variants[action[:variant_id]],
                    quantity: action[:quantity].presence&.to_i
                  }.compact
                end
              end
            end

            # @return [Hash{String => ActiveRecord::Base}] records by the prefixed id asked for
            # @raise [ActiveRecord::RecordNotFound] when any id is not in +scope+
            def resolve_ids(scope, prefixed_ids)
              prefixed_ids = prefixed_ids.compact_blank.uniq
              return {} if prefixed_ids.empty?

              records = scope.where(id: prefixed_ids.map { |prefixed_id| scope.model.decode_prefixed_id(prefixed_id) }).index_by(&:prefixed_id)
              missing = prefixed_ids - records.keys
              raise ActiveRecord::RecordNotFound.new("Couldn't find #{scope.model.name} '#{missing.first}'", scope.model.name) if missing.any?

              records
            end
          end
        end
      end
    end
  end
end
