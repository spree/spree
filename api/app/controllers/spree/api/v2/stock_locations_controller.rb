module Spree
  module Api
    module V2
      class StockLocationsController < Spree::Api::BaseController
        def index
          authorize! :read, StockLocation
          @stock_locations = StockLocation.accessible_by(current_ability, :read).order('name ASC').ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          render json: @stock_locations, meta: pagination(@stock_locations)
        end

        def show
          authorize! :read, stock_location
          render json: stock_location
        end

        def create
          authorize! :create, StockLocation
          @stock_location = StockLocation.new(stock_location_params)
          if @stock_location.save
            render json: @stock_location, status: 201
          else
            invalid_resource!(@stock_location)
          end
        end

        def update
          authorize! :update, stock_location
          if stock_location.update_attributes(stock_location_params)
            render json: stock_location
          else
            invalid_resource!(stock_location)
          end
        end

        def destroy
          authorize! :destroy, stock_location
          stock_location.destroy
          render json: stock_location, status: 204
        end

        private

        def stock_location
          @stock_location ||= StockLocation.accessible_by(current_ability, :read).find(params[:id])
        end

        def stock_location_params
          params.require(:stock_location).permit(permitted_stock_location_attributes)
        end
      end
    end
  end
end
