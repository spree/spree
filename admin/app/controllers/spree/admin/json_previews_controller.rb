module Spree
  module Admin
    class JsonPreviewsController < ResourceController
      private

      def model_class
        @model_class ||= begin
          klass_name = params[:resource_type]
          # Ensure all Spree models are loaded so that descendants is complete
          Rails.application.eager_load! unless Rails.application.config.eager_load
          klass = Spree.base_class.descendants.find { |spree_klass| spree_klass.name.to_s == klass_name }
          klass ||= Spree.user_class if klass_name == Spree.user_class.to_s
          klass ||= Spree.admin_user_class if klass_name == Spree.admin_user_class.to_s

          raise ActiveRecord::RecordNotFound if klass.blank?

          klass
        rescue NameError
          raise ActiveRecord::RecordNotFound
        end
      end
    end
  end
end
