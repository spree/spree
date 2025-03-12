module Spree
  module Admin
    class DigitalsController < ResourceController
      belongs_to 'spree/product', find_by: :slug

      private

      def create_turbo_stream_enabled?
        true
      end

      def update_turbo_stream_enabled?
        true
      end

      def destroy_turbo_stream_enabled?
        true
      end

      def permitted_resource_params
        params.require(:digital).permit(permitted_digital_attributes)
      end

      def permitted_digital_attributes
        %i[variant_id attachment]
      end
    end
  end
end
