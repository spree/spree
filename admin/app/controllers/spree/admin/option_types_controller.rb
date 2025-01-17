module Spree
  module Admin
    class OptionTypesController < ResourceController
      before_action :setup_new_option_value, only: :edit

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
    end
  end
end
