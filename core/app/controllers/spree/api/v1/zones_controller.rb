module Spree
  module Api
    module V1
      class ZonesController < Spree::Api::V1::BaseController
        def index
          @zones = Zone.order('name ASC')
        end

        def show
          zone
        end

        def create
          authorize! :create, Zone
          @zone = Zone.new(map_nested_attributes_keys(Spree::Zone, params[:zone]))
          if @zone.save
            render :show, :status => 201
          else
            invalid_resource!(@zone)
          end
        end

        def update
          authorize! :update, Zone
          if zone.update_attributes(map_nested_attributes_keys(Spree::Zone, params[:zone]))
            render :show, :status => 200
          else
            invalid_resource!(@zone)
          end
        end

        def destroy
          authorize! :delete, Zone
          zone.destroy
          render :text => nil, :status => 200
        end

        private
        def zone
          @zone ||= Spree::Zone.find(params[:id])
        end
      end
    end
  end
end
