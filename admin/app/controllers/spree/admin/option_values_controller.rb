module Spree
  module Admin
    class OptionValuesController < ResourceController
      belongs_to 'spree/option_type', find_by: :id

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
