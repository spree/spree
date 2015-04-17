module Spree
  module Api
    module V2
      class StockMovementsController < Spree::Api::BaseController
        before_action :stock_location, except: [:update, :destroy]

        def index
          authorize! :read, StockMovement
          @stock_movements = scope.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          render json: @stock_movements, meta: pagination(@stock_movements)
        end

        def show
          @stock_movement = scope.find(params[:id])
          render json: @stock_movement
        end

        def create
          authorize! :create, StockMovement
          @stock_movement = scope.new(stock_movement_params)
          if @stock_movement.save
            render json: @stock_movement, status: 201
          else
            invalid_resource!(@stock_movement)
          end
        end

        private

        def stock_location
          render json: { error: I18n.t(:stock_location_required, scope: "spree.api") }, status: 402 and return unless params[:stock_location_id]
          @stock_location ||= StockLocation.accessible_by(current_ability, :read).find(params[:stock_location_id])
        end

        def scope
          @stock_location.stock_movements.accessible_by(current_ability, :read)
        end

        def stock_movement_params
          params.require(:stock_movement).permit(permitted_stock_movement_attributes)
        end
      end
    end
  end
end
