module Spree
  module Api
    class StockItemsController < Spree::Api::BaseController
      before_action :stock_location, except: [:update, :destroy]

      def index
        @stock_items = scope.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        render json: @stock_items, meta: pagination(@stock_items)
      end

      def show
        @stock_item = scope.find(params[:id])
        render json: @stock_item
      end

      def create
        authorize! :create, StockItem

        count_on_hand = 0
        if params[:stock_item].has_key?(:count_on_hand)
          count_on_hand = params[:stock_item][:count_on_hand].to_i
        end

        @stock_item = scope.new(stock_item_params)
        if @stock_item.save
          @stock_item.adjust_count_on_hand(count_on_hand)
          render json: @stock_item, status: 201
        else
          invalid_resource!(@stock_item)
        end
      end

      def update
        @stock_item = StockItem.accessible_by(current_ability, :update).find(params[:id])

        count_on_hand = 0
        if params[:stock_item].has_key?(:count_on_hand)
          count_on_hand = params[:stock_item][:count_on_hand].to_i
          params[:stock_item].delete(:count_on_hand)
        end

        updated = params[:stock_item][:force] ? @stock_item.set_count_on_hand(count_on_hand)
                                              : @stock_item.adjust_count_on_hand(count_on_hand)

        if updated
          render json: @stock_item
        else
          invalid_resource!(@stock_item)
        end
      end

      def destroy
        @stock_item = StockItem.accessible_by(current_ability, :destroy).find(params[:id])
        @stock_item.destroy
        render json: @stock_item, status: 204
      end

      private

      def stock_location
        render json: { error: I18n.t(:stock_location_required, scope: "spree.api") }, status: 422 and return unless params[:stock_location_id]
        @stock_location ||= StockLocation.accessible_by(current_ability, :read).find(params[:stock_location_id])
      end

      def scope
        includes = {:variant => [{ :option_values => :option_type }, :product] }
        @stock_location.stock_items.accessible_by(current_ability, :read).includes(includes)
      end

      def stock_item_params
        params.require(:stock_item).permit(permitted_stock_item_attributes)
      end
    end
  end
end
