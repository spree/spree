module Spree
  module Admin
    class OptionValuesController < ResourceController
      belongs_to 'spree/option_type', find_by: :prefix_id

      def select_options
        render json: @option_type.option_values.accessible_by(current_ability).to_tom_select_json
      end

      private

      def update_turbo_stream_enabled?
        true
      end

      def location_after_save
        spree.edit_admin_option_type_path(@parent)
      end

      def permitted_resource_params
        params.require(:option_value).permit(permitted_option_value_attributes)
      end

      # for select_options action, we only require read permission
      def authorize_admin
        if action == :select_options
          authorize! :read, Spree::OptionValue
        else
          super
        end
      end
    end
  end
end
