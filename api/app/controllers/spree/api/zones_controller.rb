module Spree
  module Api
    class ZonesController < Spree::Api::BaseController
      respond_to :json

      def index
        @zones = Zone.order('name ASC').ransack(params[:q]).result.page(params[:page]).per(params[:per_page])
        respond_with(@zones)
      end

      def show
        respond_with(zone)
      end

      def create
        authorize! :create, Zone
        @zone = Zone.new(map_nested_attributes_keys(Spree::Zone, params[:zone]))
        if @zone.save
          respond_with(@zone, :status => 201, :default_template => :show)
        else
          invalid_resource!(@zone)
        end
      end

      def update
        authorize! :update, Zone
        if zone.update_attributes(map_nested_attributes_keys(Spree::Zone, params[:zone]))
          respond_with(zone, :status => 200, :default_template => :show)
        else
          invalid_resource!(zone)
        end
      end

      def destroy
        authorize! :delete, Zone
        zone.destroy
        respond_with(zone, :status => 204)
      end

      private
      def zone
        @zone ||= Spree::Zone.find(params[:id])
      end
    end
  end
end
