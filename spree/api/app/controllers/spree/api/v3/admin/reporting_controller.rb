module Spree
  module Api
    module V3
      module Admin
        # The semantic reporting surface (docs/plans/6.0-analytics-semantic-layer.md):
        # one query endpoint compiled against the Spree.reporting registry, plus
        # registry introspection for pickers and agent tool schemas.
        class ReportingController < Admin::BaseController
          scoped_resource :reports

          rescue_from Spree::Reporting::UnknownMember, Spree::Reporting::InvalidQuery, with: :render_invalid_query

          QUERY_KEYS = %w[metrics dimensions filters time_range compare sort limit currency].freeze

          # POST /api/v3/admin/reporting/query
          def query
            reporting_query = Spree::Reporting::Query.new(store: current_store, params: query_params)
            authorize_reporting_members!(reporting_query)
            result = reporting_query.execute

            render json: ReportingResultSerializer.new(
              result,
              store: current_store,
              params: serializer_params
            ).to_h
          end

          # GET /api/v3/admin/reporting/schema
          def schema
            render json: Spree.reporting.schema
          end

          private

          def action_kind
            'read'
          end

          # The contract owns shape validation (registry allowlist, loud
          # rejection of unknown members) — nothing here is mass-assigned to a
          # model, so strong-params filtering would only duplicate it.
          def query_params
            params.to_unsafe_h.slice(*QUERY_KEYS)
          end

          # JWT admins are authorized per referenced member via CanCanCan —
          # a staff role without product access cannot query the product
          # dimension. Secret-key requests are gated by the `read_reports`
          # scope instead (checked by ScopedAuthorization).
          def authorize_reporting_members!(reporting_query)
            return if current_api_key.present?

            reporting_query.required_subjects.each { |subject| authorize!(:read, subject) }
          end

          def render_invalid_query(error)
            render_error(code: 'invalid_reporting_query', message: error.message, status: :unprocessable_content)
          end
        end
      end
    end
  end
end
