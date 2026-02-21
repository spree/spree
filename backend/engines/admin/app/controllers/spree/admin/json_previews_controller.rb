module Spree
  module Admin
    class JsonPreviewsController < ResourceController
      private

      def find_resource
        model_class.find_by_prefix_id!(params[:id])
      end

      def model_class
        @model_class ||= begin
          klass_name = params[:resource_type]
          klass = klass_name.safe_constantize

          raise ActiveRecord::RecordNotFound if klass.blank?
          raise ActiveRecord::RecordNotFound unless klass <= Spree.base_class || klass == Spree.user_class || klass == Spree.admin_user_class

          klass
        end
      end
    end
  end
end
