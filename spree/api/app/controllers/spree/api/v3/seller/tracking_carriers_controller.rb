module Spree
  module Api
    module V3
      module Seller
        # The registered carriers a tracking number can be pinned to.
        #
        # Registry data (`Spree.tracking_carriers`) rather than store records,
        # so the seller's carrier picker renders from the same list the
        # operator's does and a carrier added by an extension appears without
        # a client change. Gated by `fulfillments`: a seller reads these while
        # marking a parcel sent.
        class TrackingCarriersController < Seller::BaseController
          scoped_resource :fulfillments

          # GET /api/v3/seller/tracking_carriers
          def index
            authorize! :update, Spree::Fulfillment

            data = Spree.tracking_carriers.map do |slug, carrier|
              { id: slug, name: carrier[:name] }
            end

            render json: { data: data.sort_by { |carrier| carrier[:name] } }
          end

          protected

          def read_actions
            %w[index]
          end
        end
      end
    end
  end
end
