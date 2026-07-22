module Spree
  module Api
    module V3
      module Admin
        # Point-in-time operational counts for the dashboard home. Time-series
        # analytics live in the semantic reporting endpoint (ReportingController).
        class DashboardController < Admin::BaseController
          scoped_resource :dashboard

          # GET /api/v3/admin/dashboard/operations
          def operations
            threshold = params.fetch(:low_stock_threshold, DashboardOperationsSerializer::DEFAULT_LOW_STOCK_THRESHOLD)

            serializer = DashboardOperationsSerializer.new(
              store: current_store,
              channel: requested_channel,
              low_stock_threshold: threshold.to_i.clamp(1, 1000)
            )

            render json: serializer.to_h
          end

          private

          def action_kind
            'read'
          end

          # Optional channel scoping — omitted means all channels.
          def requested_channel
            return if params[:channel_id].blank?

            current_store.channels.find_by_prefix_id!(params[:channel_id])
          end
        end
      end
    end
  end
end
