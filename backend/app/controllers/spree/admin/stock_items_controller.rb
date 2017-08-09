module Spree
  module Admin
    class StockItemsController < ResourceController
      before_action :determine_backorderable, only: :update

      def update
        @stock_item.save
        respond_to do |format|
          format.js { head :ok }
        end
      end

      def create
        stock_movement = stock_location.stock_movements.build(stock_movement_params)
        stock_movement.stock_item = stock_location.set_up_stock_item(variant)

        if stock_movement.save
          respond_to do |format|
            format.json do
              render json: {
                stock_item: stock_movement.stock_item,
                message: flash_message_for(stock_movement, :successfully_created)
              }
            end
            format.html do
              flash[:success] = flash_message_for(stock_movement, :successfully_created)
              redirect_back fallback_location: spree.stock_admin_product_url(variant.product)
            end
          end
        else
          respond_to do |format|
            format.json do
              render json: {
                errors: stock_movement.errors.full_messages + stock_movement.stock_item.errors.full_messages,
                message: Spree.t(:could_not_create_stock_movement)
              }, status: :unprocessable_entity
            end
            format.html do
              flash[:error] = Spree.t(:could_not_create_stock_movement)
              redirect_back fallback_location: spree.stock_admin_product_url(variant.product)
            end
          end
        end
      end

      def destroy
        @stock_item.destroy

        respond_with(@stock_item) do |format|
          format.html { redirect_back fallback_location: spree.stock_admin_product_url(@stock_item.product) }
          format.js
        end
      end

      private

      def stock_movement_params
        params.require(:stock_movement).permit(permitted_stock_movement_attributes)
      end

      def stock_location
        @stock_location_class ||= StockLocation.accessible_by(current_ability, :read)
        @stock_location ||= @stock_location_class.find_by(id: params[:stock_location_id]) ||
                            @stock_location_class.find_by(name: params[:stock_location]) ||
                            @stock_location_class.first
      end

      def determine_backorderable
        @stock_item.backorderable = params[:stock_item].present? && params[:stock_item][:backorderable].present?
      end

      def variant
        @variant ||= Variant.find(params[:variant_id])
      end

      def collection
        return @collection if @collection.present?
        # params[:q] can be blank upon pagination
        params[:q] = {} if params[:q].blank?
        @collection = stock_location.
                      stock_items.
                      accessible_by(current_ability, :read).
                      includes(variant: [:product, :images, option_values: :option_type]).
                      order("#{Spree::Variant.table_name}.product_id")

        @search = @collection.ransack(params[:q])
        @collection = @search.result.
                      page(params[:page]).
                      per(params[:per_page] || Spree::Config[:stock_items_per_page])
      end

      def stock_item_params
        params.require(:stock_item).permit(permitted_stock_item_attributes)
      end
    end
  end
end
