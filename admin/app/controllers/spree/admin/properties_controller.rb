module Spree
  module Admin
    class PropertiesController < ResourceController
      before_action :assign_filter_badges, only: :index

      def index
        respond_with(@collection)
      end

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

      def assign_filter_badges
        @filter_badges ||= begin
          badges = {}
          badges[:name_or_presentation_cont] = { label: Spree.t(:name), value: params[:q][:name_or_presentation_cont] } if params.dig(:q,
                                                                                                                                      :name_or_presentation_cont).present?
          badges
        end
      end
    end
  end
end
