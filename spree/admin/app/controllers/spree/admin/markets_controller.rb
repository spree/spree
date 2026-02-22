module Spree
  module Admin
    class MarketsController < ResourceController
      include Spree::Admin::SettingsConcern

      before_action :load_data, except: :index
      before_action :normalize_supported_locales, only: [:create, :update]

      protected

      def load_data
        @countries = current_store.countries_with_shipping_coverage
      end

      def permitted_resource_params
        params.require(:market).permit(permitted_market_attributes)
      end

      private

      def normalize_supported_locales
        if params.dig(:market, :supported_locales)&.is_a?(Array)
          params[:market][:supported_locales] = params[:market][:supported_locales].compact.uniq.reject(&:blank?).join(',')
        end
      end
    end
  end
end
