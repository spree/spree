module Spree
  module Admin
    class ReturnIndexController < BaseController
      def return_authorizations
        collection(Spree::ReturnAuthorization.for_store(current_store).accessible_by(current_ability, :index))
        respond_with(@collection)
      end

      def customer_returns
        collection(current_store.customer_returns.accessible_by(current_ability, :index))
        respond_with(@collection)
      end

      private

      def collection(resource)
        return @collection if @collection.present?

        params[:q] ||= {}

        # @search needs to be defined as this is passed to search_form_for
        @search = resource.ransack(params[:q])
        per_page = params[:per_page]
        @collection = @search.result.order(created_at: :desc).page(params[:page]).per(per_page)
      end

      # this is needed for proper permissions checking
      def model_class
        action == :customer_returns ? Spree::CustomerReturn : Spree::ReturnAuthorization
      end
    end
  end
end
