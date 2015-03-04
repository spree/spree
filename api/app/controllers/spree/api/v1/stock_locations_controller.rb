module Spree
  module Api
    module V1
      class StockLocationsController < Spree::Api::BaseController
        def index
          authorize! :read, StockLocation
          @stock_locations = StockLocation.accessible_by(current_ability, :read).order('name ASC').ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          respond_with(@stock_locations)
        end

        def show
          respond_with(stock_location)
        end

        def create
          authorize! :create, StockLocation
          @stock_location = StockLocation.new(stock_location_params)
          if @stock_location.save
            respond_with(@stock_location, status: 201, default_template: :show)
          else
            invalid_resource!(@stock_location)
          end
        end

        def update
          authorize! :update, stock_location
          if stock_location.update_attributes(stock_location_params)
            respond_with(stock_location, status: 200, default_template: :show)
          else
            invalid_resource!(stock_location)
          end
        end

        def destroy
          authorize! :destroy, stock_location
          stock_location.destroy
          respond_with(stock_location, :status => 204)
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
