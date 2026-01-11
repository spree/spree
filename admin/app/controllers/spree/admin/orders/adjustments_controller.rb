module Spree
  module Admin
    module Orders
      class AdjustmentsController < Spree::Admin::BaseController
        include Spree::Admin::OrderConcern

        before_action :load_order
        before_action :load_adjustment, except: [:new, :create]

        layout 'turbo_rails/frame'

        # GET /admin/orders/:order_id/adjustments/new
        def new
          @adjustment = @order.adjustments.new
        end

        # POST /admin/orders/:order_id/adjustments
        def create
          @adjustment = @order.adjustments.new(permitted_resource_params)
          @adjustment.order = @order
          @adjustment.label = params.dig(:adjustment, :label).presence || Spree.t(:manual_adjustment)
          @adjustment.state = 'closed'

          if @adjustment.save
            @order.update_with_updater!
            flash.now[:success] = Spree.t(:successfully_created, resource: Spree.t(:adjustment))

            load_order_items

            respond_to do |format|
              format.turbo_stream
              format.html { redirect_to spree.edit_admin_order_path(@order) }
            end
          else
            flash.now[:error] = @adjustment.errors.full_messages.to_sentence
            respond_to do |format|
              format.turbo_stream
              format.html { render :new, status: :unprocessable_entity }
            end
          end
        end

        # GET /admin/orders/:order_id/adjustments/:id/edit
        def edit; end

        # PATCH /admin/orders/:order_id/adjustments/:id
        def update
          if @adjustment.update(permitted_resource_params)
            @adjustment.close if @adjustment.open?
            @order.update_with_updater!
            flash.now[:success] = Spree.t(:successfully_updated, resource: Spree.t(:adjustment))

            load_order_items

            respond_to do |format|
              format.turbo_stream
              format.html { redirect_to spree.edit_admin_order_path(@order) }
            end
          else
            flash.now[:error] = @adjustment.errors.full_messages.to_sentence
            render :edit, status: :unprocessable_entity
          end
        end

        # DELETE /admin/orders/:order_id/adjustments/:id
        def destroy
          if @adjustment.destroy
            @order.update_with_updater!
            load_order_items
            flash.now[:success] = Spree.t(:successfully_removed, resource: Spree.t(:adjustment))
          else
            flash.now[:error] = @adjustment.errors.full_messages.to_sentence
          end

          respond_to do |format|
            format.turbo_stream
            format.html { redirect_to spree.edit_admin_order_path(@order) }
          end
        end

        # PUT /admin/orders/:order_id/adjustments/:id/toggle_state
        def toggle_state
          if @adjustment.closed?
            @adjustment.open
          else
            @adjustment.close
          end

          @order.update_with_updater!
          flash.now[:success] = Spree.t(:successfully_updated, resource: Spree.t(:adjustment))

          respond_to do |format|
            format.turbo_stream
            format.html { redirect_to spree.edit_admin_order_path(@order) }
          end
        end

        private

        def model_class
          Spree::Adjustment
        end

        def load_order
          @order = current_store.orders.find_by!(number: params[:order_id])
          authorize! :update, @order
        end

        def load_adjustment
          @adjustment = @order.all_adjustments.find(params[:id])
          authorize! action, @adjustment
        end

        def permitted_resource_params
          params.require(:adjustment).permit(:amount, :label)
        end
      end
    end
  end
end
