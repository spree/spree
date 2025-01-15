module Spree
  module Admin
    class OptionTypesController < ResourceController
      before_action :setup_new_option_value, only: :edit
      before_action :assign_filter_badges, only: :index

      private

      def collection
        return @collection if @collection.present?

        @collection = super

        params[:q] ||= {}
        @search = @collection.ransack(params[:q])
        @collection = @search.result.all
      end

      def setup_new_option_value
        @option_type.option_values.build if @option_type.option_values.empty?
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
