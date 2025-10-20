module Spree
  module Admin
    class ImportMappingsController < ResourceController
      belongs_to 'spree/import', find_by: :number

      def update_turbo_stream_enabled?
        true
      end

      def permitted_resource_params
        params.require(:import_mapping).permit(permitted_import_mapping_attributes)
      end
    end
  end
end
