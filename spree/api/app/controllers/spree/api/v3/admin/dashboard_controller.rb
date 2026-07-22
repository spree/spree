module Spree
  module Api
    module V3
      module Admin
        class DashboardController < Admin::BaseController
          scoped_resource :dashboard

          # GET /api/v3/admin/dashboard/analytics
          def analytics
            serializer = DashboardAnalyticsSerializer.new(
              store: current_store,
              currency: requested_currency,
              time_range: requested_time_range,
              channel: requested_channel,
              params: serializer_params
            )

            render json: serializer.to_h
          end

          # GET /api/v3/admin/dashboard/rankings
          def rankings
            serializer = DashboardRankingsSerializer.new(
              store: current_store,
              currency: requested_currency,
              time_range: requested_time_range,
              channel: requested_channel,
              limit: params.fetch(:limit, DashboardRankingsSerializer::DEFAULT_LIMIT)
            )

            render json: serializer.to_h
          end

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

          def requested_time_range
            date_from = (params[:date_from] || 30.days.ago).to_time.beginning_of_day
            date_to = (params[:date_to] || Time.current).to_time.end_of_day

            date_from..date_to
          end

          def requested_currency
            params[:currency] || current_store.default_currency
          end

          # Optional channel scoping — omitted means all channels.
          def requested_channel
            return if params[:channel_id].blank?

            current_store.channels.find_by_prefix_id!(params[:channel_id])
          end

          def serializer_params
            {
              store: current_store,
              locale: current_locale,
              currency: current_currency,
              user: current_user,
              includes: [],
              expand: []
            }
          end
        end
      end
    end
  end
end
