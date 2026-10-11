module Spree
  module Api
    module V3
      module Admin
        # The semantic reporting surface (docs/plans/6.0-analytics-semantic-layer.md):
        # one query endpoint compiled against the Spree.reporting registry, plus
        # registry introspection for pickers and agent tool schemas.
        class ReportingController < Admin::BaseController
          include ReportingAuthorization

          scoped_resource :reports

          rescue_from Spree::Reporting::UnknownMember, Spree::Reporting::InvalidQuery, with: :render_invalid_query

          QUERY_KEYS = %w[metrics dimensions filters metric_filters time_range compare sort limit currency].freeze

          request_params 'ReportingQueryParams', action: :query do
            string :metrics, array: true, required: true,
                             description: 'Registered metric names, from the reporting schema endpoint.'
            any :dimensions, array: true, description: <<~TEXT.squish
              Up to #{Spree::Reporting::Query::MAX_DIMENSIONS} dimensions to break the metrics down by. Each is a dimension
              name, or `{ name, grain, include_empty }`: `grain` (`hour`, `day`, `week`, `month`) buckets a time
              dimension, and `include_empty` lists members with no matching rows where the schema entry supports it.
            TEXT
            object :filters, array: true, description: 'Narrows the rows by dimension value.' do
              string :dimension, required: true
              string :op, required: true, enum: Spree::Reporting::Query::FILTER_OPS
              any :value, required: true, description: 'One value for `eq`, a list for `in`.'
            end
            object :metric_filters, array: true,
                                    description: "Filters on an aggregate, such as `units_sold = 0`. Narrows the rows only; the totals stay the period's real figure. The metric must also appear in `metrics`, and cannot be a derived one." do
              string :metric, required: true
              string :op, required: true, enum: Spree::Reporting::Query::METRIC_FILTER_OPS
              number :value, required: true
            end
            object :time_range,
                   description: "A named preset (`last_month`, `week_to_date`, any `last_<n>_<days|weeks|months>`), or ISO 8601 dates or times in `since` and `until` (a bare date covers the store's whole day). Defaults to the last 30 days, in the store's time zone." do
              string :preset, :since, :until
            end
            string :compare, enum: Spree::Reporting::Query::COMPARE_MODES
            string :sort, description: 'A metric name; prefix it with `-` to sort descending.'
            integer :limit, description: "At most #{Spree::Reporting::Query::MAX_LIMIT}."
            string :currency
          end

          # POST /api/v3/admin/reporting/query
          def query
            reporting_query = Spree::Reporting::Query.new(store: current_store, params: query_params)
            authorize_reporting_members!(reporting_query)
            return if performed?

            result = reporting_query.execute

            render json: ReportingResultSerializer.new(
              result,
              store: current_store,
              params: serializer_params
            ).to_h
          end

          # GET /api/v3/admin/reporting/schema
          #
          # Filtered to what this caller may reference: pickers never offer,
          # and agents never propose, a member that would be refused.
          def schema
            render json: Spree::Reporting::Schema.new(
              store: current_store,
              allowed: ->(member) { member_allowed?(member) }
            ).to_h
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

          # Both credential types are authorized per referenced member:
          # JWT admins via CanCanCan (`required_subjects`), secret keys via
          # their scopes (`required_key_scopes` on top of the `read_reports`
          # endpoint gate) — a key without `read_products` cannot query the
          # product dimension any more than a limited staff role can.
          def authorize_reporting_members!(reporting_query)
            if current_api_key.present?
              missing = reporting_query.required_key_scopes.reject { |scope| current_api_key.has_scope?(scope) }
              return if missing.empty?

              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
                message: "API key lacks scope: #{missing.join(', ')}",
                status: :forbidden,
                details: { required_scopes: missing }
              )
            else
              authorize!(:read, :reports)
              forbidden = reporting_query.unreadable_subjects(current_ability).first
              raise CanCan::AccessDenied.new(nil, :read, forbidden) if forbidden
            end
          end

          # An unknown member carries what it was and what was valid instead.
          # Passing those through as `details` lets a client correct the query
          # without parsing the sentence — the same list the schema endpoint
          # would have given it.
          def render_invalid_query(error)
            details = if error.is_a?(Spree::Reporting::UnknownMember)
                        { kind: error.kind, name: error.name.to_s, valid: error.valid.map(&:to_s) }
                      end

            render_error(code: 'invalid_reporting_query', message: error.message,
                         status: :unprocessable_content, details: details)
          end
        end
      end
    end
  end
end
