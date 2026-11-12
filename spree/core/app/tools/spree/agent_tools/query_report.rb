module Spree
  module AgentTools
    # Answers a reporting question — revenue by month, units by product,
    # orders by channel — against the same semantic registry the dashboard
    # charts read, so an agent and a chart cannot disagree about what a
    # number means.
    class QueryReport < Spree::AgentTool
      tool_name 'query_report'
      description 'Run a reporting query: pick metrics (net_sales, orders, units_sold) and ' \
                  'dimensions to group them by, and get the aggregated rows. Call ' \
                  'describe_reporting first for the exact names this store has.'
      permission 'read_reports'

      param :metrics, type: :array, items: :string,
                      description: 'Metric names, e.g. ["orders", "net_sales"]', required: true
      param :dimensions, type: :array, items: %i[string object],
                         description: 'Dimensions to group by, as named by describe_reporting ' \
                                      '(e.g. ["completed_at", "channel"]). A date dimension takes a grain as ' \
                                      '{"name": "completed_at", "grain": "month"} (hour, day, week or month); ' \
                                      'without one, the grain is picked to fit the time range. Omit for a single total.',
                         required: false
      param :time_range, type: :object,
                         description: 'A preset such as {"preset": "last_30_days"} or {"preset": "year_to_date"}, ' \
                                      'or dates as {"since": "2026-01-01", "until": "2026-03-31"}. ' \
                                      'Defaults to the last 30 days.',
                         required: false
      param :filters, type: :array, items: :object,
                      description: 'Dimension filters, each {"dimension": …, "op": "eq" or "in", "value": …} — ' \
                                   'e.g. [{"dimension": "channel", "op": "in", "value": ["web", "pos"]}]',
                      required: false
      param :sort, description: 'Metric or dimension to sort by, prefixed with - for descending', required: false
      param :limit, type: :integer, description: 'Maximum rows to return (default 50)', required: false
      param :currency, description: 'Currency for money metrics; defaults to the store currency', required: false

      # Rows land in the model's context verbatim, so a query that would have
      # returned thousands is capped rather than truncated silently.
      DEFAULT_LIMIT = 50
      MAX_LIMIT = 500
      # A date dimension given without a grain gets the finest one that keeps
      # the series about this long: a month by day, a quarter by week, a year
      # by month. The reporting default, hour, fits almost no question.
      TARGET_POINTS = 31
      GRAIN_LENGTHS = { hour: 1.hour, day: 1.day, week: 1.week, month: 1.month }.freeze
      # Models often write a range as from/to; both are read as since/until.
      TIME_RANGE_ALIASES = { 'from' => 'since', 'to' => 'until' }.freeze
      TIME_RANGE_KEYS = %w[preset since until].freeze

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
          'filters' => Array(filters),
          'limit' => [(limit || DEFAULT_LIMIT).to_i, MAX_LIMIT].min
        }
        parameters['time_range'] = normalize_time_range(time_range) if time_range.present?
        parameters['sort'] = sort if sort.present?
        parameters['currency'] = currency if currency.present?

        dimensions = Array(dimensions).map { |entry| entry.is_a?(Hash) ? entry.stringify_keys : entry }
        ungrained = dimensions.index { |entry| ungrained_time_dimension(entry) }
        return reporting_query(parameters.merge('dimensions' => dimensions)) if ungrained.nil?

        # The range decides the grain, and only the query resolves the range
        # (presets, the store's timezone), so it is built once at the coarsest
        # grain to read the range back, then again at the grain that fits.
        dimension = ungrained_time_dimension(dimensions[ungrained])
        name = dimension.name.to_s
        draft = dimensions.dup
        draft[ungrained] = { 'name' => name, 'grain' => dimension.grains.last.to_s }
        range = reporting_query(parameters.merge('dimensions' => draft)).time_range

        draft[ungrained] = { 'name' => name, 'grain' => fitting_grain(dimension, range).to_s }
        reporting_query(parameters.merge('dimensions' => draft))
      end

      def reporting_query(parameters)
        Spree::Reporting::Query.new(store: context.store, params: parameters)
      end

      # The registry's time dimension for an entry that names one without a
      # grain, or nil. Anything else is left for the query to accept or refuse.
      def ungrained_time_dimension(entry)
        return if entry.is_a?(Hash) && entry['grain'].present?

        name = entry.is_a?(Hash) ? entry['name'] : entry
        return unless name.is_a?(String) || name.is_a?(Symbol)

        dimension = Spree.reporting.dimensions[name.to_sym]
        dimension if dimension&.time?
      end

      def fitting_grain(dimension, range)
        length = range.last - range.first
        dimension.grains.find { |grain| GRAIN_LENGTHS[grain] && length / GRAIN_LENGTHS[grain] <= TARGET_POINTS } ||
          dimension.grains.last
      end

      # A range in a shape the query does not read would be dropped there for
      # the last 30 days, and the model would report on the wrong period.
      def normalize_time_range(range)
        return range unless range.is_a?(Hash)

        range = range.to_h.stringify_keys.transform_keys { |key| TIME_RANGE_ALIASES.fetch(key, key) }
        unknown = range.keys - TIME_RANGE_KEYS
        if unknown.any?
          raise Spree::Reporting::InvalidQuery,
                "time_range does not take #{unknown.join(', ')}. Use {\"preset\": …} or {\"since\": …, \"until\": …}."
        end

        range
      end

      # The same per-member check the reporting endpoint makes, in the same
      # two flavours: a key is checked against its scopes, an admin against
      # their ability. A caller who may read orders but not products cannot
      # reach the product dimension here either.
      def unauthorized_members(query)
        # Asked of the context for every principal, not just a key.
        #
        # `context.ability` is the staff member's whole role, so a token
        # granted `read_reports` and `read_orders` could group by the product
        # dimension its merchant never consented to. `holds?` is the narrowed
        # answer: a key's scopes, or a grant's, or the role when the person is
        # acting directly.
        missing = query.required_key_scopes.reject { |scope| context.holds?(scope) }
        return if missing.empty?

        { error: "You do not have permission to report on #{missing.to_sentence.delete_prefix('read_').tr('_', ' ')}." }
      end

      # Totals first: most reporting questions are answered by them alone,
      # and the rows are what fills a context window.
      #
      # Dimension keys are hydrated the same way the Admin API hydrates them.
      # A grouped row holds a raw primary key, and handing a model
      # `{"product": 3}` answers "which products sell best" with a number it
      # cannot read — the label is the answer.
      def shape(result)
        hydration = Spree::Reporting::Hydration.new(result, store: context.store)
        rows = Array(result.rows).map { |row| hydrate_row(row, hydration) }

        {
          totals: result.totals,
          rows: rows,
          row_count: rows.length,
          meta: result.meta
        }.compact
      end

      # Only the label and the id: the API's shape also carries slugs and
      # thumbnail URLs, which cost context and answer nothing a report was
      # asked.
      def hydrate_row(row, hydration)
        dimensions = (row[:dimensions] || {}).to_h do |name, raw|
          value = hydration.value(name, raw)
          [name, value.is_a?(Hash) ? value.values_at(:label, :id).compact.first : value]
        end

        row.merge(dimensions: dimensions)
      end

    end
  end
end
