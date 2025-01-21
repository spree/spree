module Spree
  module Admin
    class ZonesController < ResourceController
      before_action :load_data, except: :index

      def new
        @zone.zone_members.build
      end

      protected

      def location_after_save
        edit_object_url(@object, states_country_id: @selected_country&.id)
      end

      def collection
        params[:q] ||= {}
        params[:q][:s] ||= 'name asc'
        @search = super.ransack(params[:q])
        @zones = @search.result.page(params[:page]).per(params[:per_page])
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
    end
  end
end
