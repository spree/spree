module Spree
  module Api
    module V1
      class ReimbursementsController < Spree::Api::BaseController
        def index
          collection(Spree::Reimbursement)
          respond_with(@collection)
        end

        private

        def collection(resource)
          return @collection if @collection.present?

          params[:q] ||= {}

          @collection = resource.all
          # @search needs to be defined as this is passed to search_form_for
          @search = @collection.ransack(params[:q])
          @collection = @search.result.order(created_at: :desc).page(params[:page]).per(params[:per_page])
        end
      end
    end
  end
end
