module Spree
  module Admin
    class PaymentMethodsController < ResourceController
      prepend_before_action :require_payment_type, only: [:new, :create]
      before_action :clear_empty_password_preferences, only: :update

      private

      def build_resource
        @object = params[:payment_method].delete(:type).constantize.new if params[:payment_method].present?
      end

      def collection
        return @collection if @collection.present?

        params[:q] ||= {}

        @collection = super.order(position: :asc)
        @search = @collection.ransack(params[:q])
        @collection = @search.result.page(params[:page]).per(params[:per_page])
      end

      def update_turbo_stream_enabled?
        true
      end

      def require_payment_type
        redirect_to spree.admin_payment_methods_path unless params.dig(:payment_method, :type).present?
      end

      def clear_empty_password_preferences
        if params[:payment_method].present?
          password_preferences = @object.preferences_of_type(:password)
          password_preferences.each do |preference|
            preference_key = "preferred_#{preference}"

            if params.dig(:payment_method, preference_key).blank? && @object.preferences[preference].present?
              params[:payment_method].delete(preference_key)
            end
          end
        end
      end
    end
  end
end
