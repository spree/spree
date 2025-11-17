module Spree
  module Admin
    class ZonesController < ResourceController
      include Spree::Admin::SettingsConcern
      before_action :load_data, except: :index

      def new
        @zone.zone_members.build
      end

      protected

      def location_after_save
        edit_object_url(@object, states_country_id: @selected_country&.id)
      end

      def load_data
        @selected_country = if params[:states_country_id]
          Spree::Country.find_by(id: params[:states_country_id])
        elsif @zone && @zone.state? && @zone.zone_members.exists?
          @zone.zone_members.first.zoneable.country
        else
          current_store.default_country
        end
        @countries = Country.order(:name)
        @states = @selected_country&.states&.order(:name) || Spree::State.none
        @zones = Zone.order(:name)
      end

      def permitted_resource_params
        params.require(:zone).permit(permitted_zone_attributes)
      end
    end
  end
end
