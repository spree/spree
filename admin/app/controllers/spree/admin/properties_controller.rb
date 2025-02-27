module Spree
  module Admin
    class PropertiesController < ResourceController
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
    end
  end
end
