module Spree
  module Api
    class StockMovementsController < Spree::Api::BaseController
      before_filter :stock_location, except: [:update, :destroy]

      def index
        @stock_movements = scope.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@stock_movements)
      end

      def show
        @stock_movement = scope.find(params[:id])
        respond_with(@stock_movement)
      end

      def create
        authorize! :create, StockMovement
        @stock_movement = scope.new(params[:stock_movement])
        if @stock_movement.save
          respond_with(@stock_movement, status: 201, default_template: :show)
        else
          invalid_resource!(@stock_movement)
        end
      end

      def update
        authorize! :update, StockMovement
        @stock_movement = StockMovement.find(params[:id])
        if @stock_movement.update_attributes(params[:stock_movement])
          respond_with(@stock_movement, status: 200, default_template: :show)
        else
          invalid_resource!(@stock_movement)
        end
      end

      def destroy
        authorize! :delete, StockMovement
        @stock_movement = StockMovement.find(params[:id])
        @stock_movement.destroy
        respond_with(@stock_movement, status: 204)
      end

      private

      def stock_location
        render :stock_location_required, status: 422 and return unless params[:stock_location_id]
        @stock_location ||= StockLocation.find(params[:stock_location_id])
      end

      def scope
        @stock_location.stock_movements
      end
    end
  end
end
