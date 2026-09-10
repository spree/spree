module Spree
  module Api
    module V3
      module Admin
        # Point-in-time operational counts for the dashboard home, evaluated
        # from the counters registered on Spree.reporting. Time-series
        # analytics live in the semantic reporting endpoint (ReportingController).
        class DashboardController < Admin::BaseController
          include ReportingAuthorization

          scoped_resource :dashboard

          # GET /api/v3/admin/dashboard/operations
          #
          # Filtered to the counters this caller may read, so a limited role
          # gets a shorter list rather than a refused card.
          def operations
            channel = requested_channel
            counters = Spree::Reporting::Counters.new(
              store: current_store,
              channel: channel,
              allowed: ->(counter) { member_allowed?(counter) }
            )

            render json: {
              channel_id: channel&.prefixed_id,
              counters: DashboardCounterSerializer.new(counters.to_a).serializable_hash
            }
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
