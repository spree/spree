module Spree
  module Api
    module V3
      module Admin
        class TrackingCarriersController < ResourceController
          scoped_resource :fulfillments

          # GET /api/v3/admin/tracking_carriers
          #
          # The registered carriers a tracking number can be pinned to
          # (Spree.tracking_carriers), so the carrier picker renders from the
          # registry — extensions and host apps that add carriers appear
          # without any client change.
          def index
            authorize! :update, Spree::Fulfillment

            data = Spree.tracking_carriers.map do |slug, carrier|
              { id: slug, name: carrier[:name] }
            end

            render json: { data: data.sort_by { |carrier| carrier[:name] } }
          end

          protected

          def model_class
            Spree::Fulfillment
          end
        end
      end
    end
  end
end
