module Spree
  module Admin
    class PropertiesController < ResourceController
      include ProductsBreadcrumbConcern
      add_breadcrumb Spree.t(:properties), :admin_properties_path

      before_action :add_breadcrumbs

      protected

      def update_turbo_stream_enabled?
        true
      end

      def collection
        return @collection if @collection.present?

        # params[:q] can be blank upon pagination
        params[:q] = {} if params[:q].blank?

        @collection = super
        @search = @collection.ransack(params[:q])
        @collection = @search.result.
                      page(params[:page])
      end

      def add_breadcrumbs
        if @property.present? && @property.persisted?
          add_breadcrumb @property.presentation, spree.edit_admin_property_path(@property)
        end
      end

      def permitted_resource_params
        params.require(:property).permit(permitted_property_attributes)
      end
    end
  end
end
