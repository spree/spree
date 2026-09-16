module Spree
  module AgentTools
    # Answers a reporting question — revenue by month, units by product,
    # orders by channel — against the same semantic registry the dashboard
    # charts read, so an agent and a chart cannot disagree about what a
    # number means.
    class QueryReport < Spree::AgentTool
      tool_name 'query_report'
      description 'Run a reporting query: pick metrics (revenue, orders, units) and dimensions ' \
                  '(time, product, channel, country) and get the aggregated rows. Call ' \
                  'describe_reporting first for the metrics and dimensions this store has.'
      permission 'read_reports'

      param :metrics, type: :array, description: 'Metric names, e.g. ["revenue", "orders"]', required: true
      param :dimensions, type: :array,
                         description: 'Dimensions to group by, e.g. ["time.month", "product"]. Omit for a single total.',
                         required: false
      param :time_range, type: :object,
                         description: 'A preset such as {"preset": "last_30_days"}, or {"from": "2026-01-01", "to": "2026-03-31"}',
                         required: false
      param :filters, type: :array, description: 'Dimension filters, e.g. [{"dimension": "channel", "values": ["web"]}]', required: false
      param :sort, description: 'Metric or dimension to sort by, prefixed with - for descending', required: false
      param :limit, type: :integer, description: 'Maximum rows to return (default 50)', required: false
      param :currency, description: 'Currency for money metrics; defaults to the store currency', required: false

      # Rows land in the model's context verbatim, so a query that would have
      # returned thousands is capped rather than truncated silently.
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 500

      def call(metrics:, dimensions: nil, time_range: nil, filters: nil, sort: nil, limit: nil, currency: nil)
        query = build_query(metrics: metrics, dimensions: dimensions, time_range: time_range,
                            filters: filters, sort: sort, limit: limit, currency: currency)

        refusal = unauthorized_members(query)
        return refusal if refusal

        shape(query.execute)
      rescue Spree::Reporting::UnknownMember => e
        { error: e.message, valid: Array(e.valid).map(&:to_s) }
      rescue Spree::Reporting::InvalidQuery => e
        { error: e.message }
      end

      def summary(arguments)
        metrics = Array(arguments[:metrics]).join(', ')
        dimensions = Array(arguments[:dimensions])

        dimensions.any? ? "Report #{metrics} by #{dimensions.join(', ')}" : "Report #{metrics}"
      end

      private

      def build_query(metrics:, dimensions:, time_range:, filters:, sort:, limit:, currency:)
        parameters = {
          'metrics' => Array(metrics),
          'dimensions' => Array(dimensions),
          'filters' => Array(filters),
          'limit' => [(limit || DEFAULT_LIMIT).to_i, MAX_LIMIT].min
        }
        parameters['time_range'] = time_range if time_range.present?
        parameters['sort'] = sort if sort.present?
        parameters['currency'] = currency if currency.present?

        Spree::Reporting::Query.new(store: context.store, params: parameters)
      end

      # The same per-member check the reporting endpoint makes, in the same
      # two flavours: a key is checked against its scopes, an admin against
      # their ability. A caller who may read orders but not products cannot
      # reach the product dimension here either.
      def unauthorized_members(query)
        if context.user_principal?
          forbidden = query.unreadable_subjects(context.ability).first
          return if forbidden.nil?

          { error: "You do not have permission to report on #{forbidden.to_s.demodulize.underscore.humanize.downcase}." }
        else
          missing = query.required_key_scopes.reject { |scope| context.api_key.has_scope?(scope) }
          return if missing.empty?

          { error: "This API key lacks the #{missing.to_sentence} scope." }
        end
      end

      # Totals first: most reporting questions are answered by them alone,
      # and the rows are what fills a context window.
      def shape(result)
        rows = Array(result.rows)

        {
          totals: result.totals,
          rows: rows,
          row_count: rows.length,
          meta: result.meta
        }.compact
      end

    end
  end
end
