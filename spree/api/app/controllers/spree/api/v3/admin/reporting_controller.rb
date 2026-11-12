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

          request_params 'ReportingQueryParams', action: :query do |body|
            body.attribute :metrics, :array, of: :string,
              required: true,
              description: 'Registered metric names, from the reporting schema endpoint.'
            body.attribute :dimensions, :array, of: :any, permit: false, description: <<~TEXT.squish
              Up to #{Spree::Reporting::Query::MAX_DIMENSIONS} dimensions to break the metrics down by. Each is a dimension
              name, or `{ name, grain, include_empty }`: `grain` (`hour`, `day`, `week`, `month`) buckets a time
              dimension, and `include_empty` lists members with no matching rows where the schema entry supports it.
            TEXT
            body.attribute :filters, :array, description: 'Narrows the rows by dimension value.' do |filter|
              filter.attribute :dimension, :string, required: true
              filter.attribute :op, :string, required: true, choices: Spree::Reporting::Query::FILTER_OPS
              filter.attribute :value, :any, required: true, description: 'One value for `eq`, a list for `in`.'
            end
            body.attribute :metric_filters, :array,
              description: "Filters on an aggregate, such as `units_sold = 0`. Narrows the rows only; the totals stay the period's real figure. The metric must also appear in `metrics`, and cannot be a derived one." do |metric_filter|
              metric_filter.attribute :metric, :string, required: true
              metric_filter.attribute :op, :string,
                required: true,
                choices: Spree::Reporting::Query::METRIC_FILTER_OPS
              metric_filter.attribute :value, :number, required: true
            end
            body.attribute :time_range, :object,
              description: "A named preset (`last_month`, `week_to_date`, any `last_<n>_<days|weeks|months>`), or ISO 8601 dates or times in `since` and `until` (a bare date covers the store's whole day). Defaults to the last 30 days, in the store's time zone." do |time_range|
              time_range.attribute :preset, :string
              time_range.attribute :since, :string
              time_range.attribute :until, :string
            end
            body.attribute :compare, :string, choices: Spree::Reporting::Query::COMPARE_MODES
            body.attribute :sort, :string, description: 'A metric name; prefix it with `-` to sort descending.'
            body.attribute :limit, :integer, description: "At most #{Spree::Reporting::Query::MAX_LIMIT}."
            body.attribute :currency, :currency
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

          # Every referenced member is authorized against what this
          # credential holds, on top of the `read_reports` endpoint gate: a
          # caller without `read_products` cannot query the product dimension
          # whatever its principal type.
          #
          # Asked through `holds_permission?` rather than of the ability,
          # because an OAuth grant authenticates as the staff member who
          # approved it and carries no API key. Measured against their role,
          # a grant for `read_reports` alone could group by customer and read
          # names, emails and spend — data the merchant never consented to.
          def authorize_reporting_members!(reporting_query)
            missing = reporting_query.required_key_scopes.reject { |scope| holds_permission?(scope) }

            if missing.any?
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:access_denied],
                message: "Missing permission: #{missing.join(', ')}",
                status: :forbidden,
                details: { required_scopes: missing }
              )
            end

            # Then the record-level rules, which a host app uses to narrow
            # what a role sees within data it may read at all.
            authorize!(:read, :reports)
            forbidden = reporting_query.unreadable_subjects(current_ability).first
            raise CanCan::AccessDenied.new(nil, :read, forbidden) if forbidden
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
