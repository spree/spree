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
                      resource_type.friendly.find(params[:id])
                    else
                      resource_type.find(params[:id])
                    end
      end

      def resource_type
        @resource_type ||= begin
          klass_name = params[:resource_type]
          klass_name.constantize if klass_name.present? && klass_name.start_with?('Spree::')
        rescue NameError
          nil
        end
      end
    end
  end
end
