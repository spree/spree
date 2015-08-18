module Spree
  module Admin
    class ReturnIndexController < BaseController
      def return_authorizations
        @collection = collection(Spree::ReturnAuthorization)
        respond_with(@collection)
      end

      def customer_returns
        @collection = collection(Spree::CustomerReturn)
        respond_with(@collection)
      end

      private

      def collection(resource)
        return @collection if @collection.present?
        params[:q] ||= {}


        if params[:q][:not_reimbursed]
          # results of 2 scopes to show the not reimbursed customer returns
          # looking forward to https://github.com/rails/rails/pull/16052
          ids = (resource.without_reimbursements.ids + resource.with_pending_reimbursements.ids) - resource.with_reimbursed_reimbursements.ids
          @collection = resource.where(id: ids)
        else
          @collection = resource.all
        end

        # @search needs to be defined as this is passed to search_form_for
        @search = @collection.ransack(params[:q])
        @collection = @search.result.
              page(params[:page]).
              per(params[:per_page] || Spree::Config[:admin_products_per_page])

        @collection
      end
    end
  end
end
