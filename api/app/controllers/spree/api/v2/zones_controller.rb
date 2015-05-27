module Spree
  module Api
    module V2
      class ZonesController < Spree::Api::BaseController
        def create
          authorize! :create, Zone
          @zone = Zone.new(map_nested_attributes_keys(Spree::Zone, zone_params))
          if @zone.save
            render json: @zone, status: 201
          else
            invalid_resource!(@zone)
          end
        end

        def destroy
          authorize! :destroy, zone
          zone.destroy
          render nothing: true, status: 204
        end

        def index
          @zones = Zone.accessible_by(current_ability, :read).order('name ASC').ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
          render json: @zones, meta: pagination(@zones)
        end

        def show
          render json: zone
        end

        def update
          authorize! :update, zone
          if zone.update_attributes(map_nested_attributes_keys(Spree::Zone, zone_params))
            render json: zone
          else
            invalid_resource!(zone)
          end
        end

        private

        def zone_params
          params.require(:zone).permit!
        end

        def zone
          @zone ||= Spree::Zone.accessible_by(current_ability, :read).find(params[:id])
        end
      end
    end
  end
end
