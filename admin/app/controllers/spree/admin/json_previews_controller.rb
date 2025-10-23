module Spree
  module Admin
    class JsonPreviewsController < BaseController
      before_action :load_resource

      def show
        @api_type = params[:api_type].presence&.to_sym || :storefront
      end

      private

      def load_resource
        raise ActiveRecord::RecordNotFound if params[:resource_type].blank?
        raise ActiveRecord::RecordNotFound if resource_type.blank?

        @resource = if resource_type.respond_to?(:friendly)
                      resource_type.friendly.accessible_by(current_ability, :read).find(params[:id])
                    else
                      resource_type.accessible_by(current_ability, :read).find(params[:id])
                    end
      end

      def resource_type
        @resource_type ||= begin
          klass_name = params[:resource_type]
          # Ensure all Spree models are loaded so that descendants is complete
          Rails.application.eager_load! unless Rails.application.config.eager_load
          klass = Spree.base_class.descendants.find { |spree_klass| spree_klass.name.to_s == klass_name }
          klass ||= Spree.user_class if klass_name == Spree.user_class.to_s
          klass ||= Spree.admin_user_class if klass_name == Spree.admin_user_class.to_s
          klass
        rescue NameError
          nil
        end
      end
    end
  end
end
