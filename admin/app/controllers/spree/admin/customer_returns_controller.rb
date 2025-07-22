module Spree
  module Admin
    class CustomerReturnsController < ResourceController
      add_breadcrumb_icon 'receipt-refund'
      add_breadcrumb Spree.t(:returns), :admin_customer_returns_path
      add_breadcrumb Spree.t(:customer_returns), :admin_customer_returns_path

      def index; end

      private

      def collection
        return @collection if @collection.present?

        params[:q] ||= {}

        # @search needs to be defined as this is passed to search_form_for
        @search = current_store.customer_returns.accessible_by(current_ability, :index).ransack(params[:q])
        per_page = params[:per_page]
        @collection = @search.result.order(created_at: :desc).page(params[:page]).per(per_page)
      end
    end
  end
end
