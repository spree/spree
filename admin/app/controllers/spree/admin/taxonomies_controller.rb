module Spree
  module Admin
    class TaxonomiesController < ResourceController
      before_action :assign_filter_badges, only: :index

      private

      def collection
        return @collection if @collection.present?

        @collection = super

        params[:q] ||= {}
        @search = @collection.ransack(params[:q])
        @collection = @search.result.all
      end

      def location_after_save
        spree.admin_taxonomy_path(@taxonomy)
      end

      def assign_filter_badges
        @filter_badges ||= begin
          badges = {}
          badges[:name_cont] = { label: Spree.t(:name), value: params[:q][:name_cont] } if params.dig(:q, :name_cont).present?
          badges
        end
      end
    end
  end
end
