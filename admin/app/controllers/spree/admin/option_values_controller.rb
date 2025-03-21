module Spree
  module Admin
    class OptionValuesController < ResourceController
      belongs_to 'spree/option_type', find_by: :id

      def select_options
        render json: @option_type.option_values.to_tom_select_json
      end

      private

      def update_turbo_stream_enabled?
        true
      end

      def location_after_save
        spree.edit_admin_option_type_path(@parent)
      end
    end
  end
end
