module Spree
  module Api
    module V3
      module Admin
        module Orders
          # An order's timeline, newest first, and the comments staff leave
          # on it (docs/plans/6.1-order-timeline.md). Entries are written by
          # the steps they record; the only thing written here is a comment.
          class ActivitiesController < BaseController
            scoped_resource :orders

            request_params :order_activity do |body|
              body.attribute :body, :string, required: true, description: 'The comment.'
            end

            # POST /api/v3/admin/orders/:order_id/activities
            def create
              @resource = @parent.activities.comments.new(body: permitted_params[:body], actor: current_actor)
              authorize_resource!(@resource, :create)

              save_and_render(@resource, status: :created)
            end

            # DELETE /api/v3/admin/orders/:order_id/activities/:id
            #
            # Only by whoever wrote it; the model refuses anything but a comment.
            def destroy
              if @resource.comment? && @resource.actor != current_actor
                return render_error(code: ERROR_CODES[:access_denied], message: I18n.t('spree.order_activity_not_deletable'),
                                    status: :forbidden)
              end

              super
            end

            protected

            def model_class
              Spree::OrderActivity
            end

            def serializer_class
              Spree.api.admin_order_activity_serializer
            end

            def collection_includes
              includes = []
              includes << :actor if expand_list.include?('actor')
              if expand_list.any? { |expand| expand.start_with?('order_change') }
                actions = [:fulfillment, :delivery_method]
                actions << { variant: OrderChangesController.variant_includes } if expand_list.include?('order_change.actions.variant')
                includes << { order_change: [:order, :return, :exchange, :claim, { actions: actions }] }
              end
              includes
            end

            # Newest first unless the caller sorts.
            def apply_collection_sort(collection)
              sort_param.present? ? collection : collection.order(created_at: :desc, id: :desc)
            end
          end
        end
      end
    end
  end
end
