module Spree
  module Api
    module V1
      class ClassificationsController < Spree::Api::BaseController
        def update
          authorize! :update, Product
          authorize! :update, Taxon
          classification = Spree::Classification.find_by(
            product_id: params[:product_id],
            taxon_id: params[:taxon_id]
          )
          Spree::Dependencies.classification_reposition_service.constantize.call(
            classification: classification,
            position: params[:position]
          )
          head :ok
        end
      end
    end
  end
end
