module Spree
  module Api
    module V1
      class CustomerReturnsController < Spree::Api::BaseController

        def index
          collection(Spree::CustomerReturn)
          respond_with(@collection)
        end

        private

        def collection(resource)
          return @collection if @collection.present?
          params[:q] ||= {}

          @collection = resource.all
          # @search needs to be defined as this is passed to search_form_for
          @search = @collection.ransack(params[:q])
          per_page = params[:per_page] || Spree::Config[:admin_customer_returns_per_page]
          @collection = @search.result.order(created_at: :desc).page(params[:page]).per(per_page)
        end

      end
    end
  end
end
