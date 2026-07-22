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

          # Authorization subjects referenced by registry members (`subject:`).
          # Every reporting query is order data, so `:read Spree::Order` is the
          # floor; members that expose other resources (product names, customer
          # identities) additionally require read on that subject.
          SUBJECT_CLASSES = {
            order: -> { Spree::Order },
            product: -> { Spree::Product },
            category: -> { Spree::Taxon },
            customer: -> { Spree.user_class },
            channel: -> { Spree::Channel }
          }.freeze

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

          # JWT admins are authorized per referenced member via CanCanCan —
          # a staff role without product access cannot query the product
          # dimension. Secret-key requests are gated by the `read_reports`
          # scope instead (checked by ScopedAuthorization).
          def authorize_reporting_members!(reporting_query)
            return if current_api_key.present?

            subjects = [:order]
            subjects += reporting_query.metrics.map(&:subject)
            subjects += (reporting_query.dimensions.map { |d| d[:dimension] } +
                         reporting_query.filters.map { |f| f[:dimension] }).map(&:subject)

            subjects.compact.uniq.each do |subject|
              resolver = SUBJECT_CLASSES[subject]
              authorize!(:read, resolver.call) if resolver
            end
          end

          def query_params
            params.permit(
              :compare, :sort, :limit, :currency,
              metrics: [],
              dimensions: [:name, :grain],
              filters: [:dimension, :op, :value, { value: [] }],
              time_range: [:since, :until]
            ).to_h.tap do |permitted|
              # `dimensions` accepts plain names or { name:, grain: } objects.
              permitted[:dimensions] = Array(params[:dimensions]).map do |dim|
                dim.is_a?(String) ? dim : dim.permit(:name, :grain).to_h
              end if params[:dimensions].present?
            end
          end

          def render_invalid_query(error)
            render json: { error: error.message, code: 'invalid_reporting_query' }, status: :unprocessable_content
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
