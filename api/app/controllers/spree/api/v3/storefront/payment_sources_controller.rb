module Spree
  module Api
    module V3
      module Storefront
        class PaymentSourcesController < BaseController
          before_action :require_authentication!
          before_action :set_payment_source, only: [:show, :destroy]

          # GET /api/v3/storefront/customers/me/payment_sources
          def index
            @payment_sources = current_user.credit_cards

            render json: {
              data: serialize_collection(@payment_sources)
            }
          end

          # GET /api/v3/storefront/customers/me/payment_sources/:id
          def show
            render json: serialize_resource(@payment_source)
          end

          # DELETE /api/v3/storefront/customers/me/payment_sources/:id
          def destroy
            @payment_source.destroy
            head :no_content
          end

          protected

          def set_payment_source
            @payment_source = current_user.credit_cards.find(params[:id])
          end

          def serialize_collection(collection)
            collection.map { |item| serialize_resource(item) }
          end

          def serialize_resource(resource)
            {
              id: resource.id,
              cc_type: resource.cc_type,
              last_digits: resource.last_digits,
              month: resource.month,
              year: resource.year,
              name: resource.name
            }
          end
        end
      end
    end
  end
end
