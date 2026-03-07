module Spree
  module Api
    module V3
      module Admin
        module Orders
          class AdjustmentsController < BaseController
            # POST /api/v3/admin/orders/:order_id/adjustments
            def create
              with_order_lock do
                @resource = @parent.adjustments.build(
                  amount: params[:amount],
                  label: params[:label],
                  order: @parent
                )
                authorize_resource!(@resource, :create)

                if @resource.save
                  @parent.update_with_updater!
                  render json: serialize_resource(@resource), status: :created
                else
                  render_validation_error(@resource.errors)
                end
              end
            end

            # PATCH /api/v3/admin/orders/:order_id/adjustments/:id
            def update
              with_order_lock do
                if @resource.update(permitted_params)
                  @parent.update_with_updater!
                  render json: serialize_resource(@resource)
                else
                  render_validation_error(@resource.errors)
                end
              end
            end

            # DELETE /api/v3/admin/orders/:order_id/adjustments/:id
            def destroy
              with_order_lock do
                @resource.destroy!
                @parent.update_with_updater!
                head :no_content
              end
            end

            protected

            def model_class
              Spree::Adjustment
            end

            def serializer_class
              Spree.api.admin_adjustment_serializer
            end

            def parent_association
              :adjustments
            end

            def permitted_params
              params.permit(:amount, :label, :eligible)
            end
          end
        end
      end
    end
  end
end
