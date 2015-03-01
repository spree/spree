module Spree
  module Api
    module V1
      class StockMovementsController < Spree::Api::BaseController
        before_action :stock_location, except: [:update, :destroy]

        def index
          authorize! :read, StockMovement
          @stock_movements = scope.ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          respond_with(@stock_movements)
        end

        def show
          @stock_movement = scope.find(params[:id])
          respond_with(@stock_movement)
        end

        def create
          authorize! :create, StockMovement
          @stock_movement = scope.new(stock_movement_params)
          if @stock_movement.save
            respond_with(@stock_movement, status: 201, default_template: :show)
          else
            invalid_resource!(@stock_movement)
          end
        end

        private

        def stock_location
          render 'spree/api/v1/shared/stock_location_required', status: 422 and return unless params[:stock_location_id]
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
