module Spree
  module Admin
    class PaymentMethodsController < ResourceController
      include Spree::Admin::PreferencesConcern
      add_breadcrumb Spree.t(:payment_methods), :admin_payment_methods_path

      prepend_before_action :require_payment_type, only: [:new, :create]
      before_action -> { clear_empty_password_preferences(:payment_method) }, only: :update
      before_action :set_breadcrumb, only: :edit

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

      def set_breadcrumb
        add_breadcrumb @payment_method.name, spree.edit_admin_payment_method_path(@payment_method)
      end
    end
  end
end
