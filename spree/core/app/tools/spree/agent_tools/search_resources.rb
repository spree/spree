module Spree
  module AgentTools
    # Searches store records, through the Admin API's own list operation.
    #
    # Filters, sorting, pagination, store scoping and record-level permissions
    # are the endpoint's, not this tool's. That is the point: the tool used to
    # call `.ransack` itself and skipped the step that decodes prefixed ids,
    # so filtering by an id it had just handed the model matched nothing and
    # reported it as a fact.
    class SearchResources < Spree::AgentTool
      DEFAULT_LIMIT = 10
      MAX_LIMIT = 25

      tool_name 'search_resources'
      description 'Search the store. Filters are Ransack predicates ' \
                  '(name_cont, created_at_gteq, status_eq) or named scopes passed as a ' \
                  'bare key, e.g. {"out_of_stock": true} for stock questions or ' \
                  '{"price_lte": 20} for price. Call describe_resource to see every ' \
                  'resource, field and scope available.'
      # Per-resource permissions are the endpoint's to enforce — it answers
      # 403 for a scope the credential lacks. This tool is offered whenever
      # the caller can read anything at all.
      permission nil

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :filters, type: :object, description: 'Ransack filter hash, e.g. {"name_cont": "shirt"}'
      param :sort, description: 'Sort, e.g. "created_at desc"'
      param :limit, type: :integer, description: "Max records to return (default #{DEFAULT_LIMIT})"

      def call(resource:, filters: nil, sort: nil, limit: nil)
        entry = ResourceMap.find(resource)
        return unknown_resource(resource) if entry.nil?
        return not_searchable(entry) unless entry.dispatchable?
        return forbidden(entry) unless context.permitted?(entry.permission)

        applied = sanitize_filters(filters)
        # Ransack drops a filter it does not recognise and returns the whole
        # collection, which a model reports as the answer ("you have 38
        # products with status notreal"). The Admin API will refuse those
        # itself once strict filters land; until then this is the only thing
        # between a typo and a confident wrong answer, so it stays.
        unrecognised = unrecognised_filters(entry, applied)
        return invalid_filters(entry, unrecognised) if unrecognised.any?

        response = dispatch.call(
          method: :get,
          path: entry.api_path(:index),
          params: query_for(applied, sort, limit)
        )
        return { error: response.error_message } unless response.success?

        rows = Array(response.data)
        meta = response.meta || {}

        {
          resource: entry.key,
          # What the endpoint counted, not what this page holds — the model is
          # asked how many there are, and would otherwise say "10 products"
          # for a store holding hundreds.
          total: meta['count'] || rows.size,
          count: rows.size,
          records: rows.map { |row| RecordSummary.from_payload(entry: entry, payload: row) }
        }
      end

      def summary(arguments)
        label = arguments[:resource].to_s.tr('_', ' ')
        filters = arguments[:filters]
        return "Search #{label}" if filters.blank?

        described = filters.keys.map { |key| key.to_s.tr('_', ' ') }.join(', ')
        "Search #{label} by #{described}"
      end

      private

      def dispatch
        @dispatch ||= ApiDispatch.new(context)
      end

      # Ransack filters travel under `q`, the way every other client sends
      # them — so an unknown one is refused by the API's own filter
      # validation rather than silently widening the search here.
      def query_for(filters, sort, limit)
        params = { limit: capped_limit(limit) }
        params[:q] = filters if filters.any?
        params[:sort] = sort if sort.present?
        params
      end

      # Empty values match everything, so they are dropped — but `false` is a
      # real filter value (`{"out_of_stock": false}`), which `compact_blank`
      # would have thrown away.
      def sanitize_filters(filters)
        (filters || {}).to_h.reject { |_key, value| value.nil? || value == '' }
      end

      def capped_limit(limit)
        return DEFAULT_LIMIT if limit.blank?

        [[limit.to_i, 1].max, MAX_LIMIT].min
      end

      # A filter key is either a named scope (`out_of_stock`) or an
      # `<attribute>_<predicate>` pair. BOTH halves are checked, because
      # checking only the attribute prefix let `status_notarealpredicate`
      # through.
      def unrecognised_filters(entry, filters)
        scopes = entry.filterable_scopes

        filters.keys.reject do |key|
          name = key.to_s
          scopes.include?(name) || valid_attribute_predicate?(entry, name)
        end
      end

      # Longest attribute first, so a field whose name is a prefix of another
      # (`name` vs `name_of_thing`) does not shadow it.
      def valid_attribute_predicate?(entry, key)
        entry.filterable_fields.sort_by { |field| -field.length }.any? do |field|
          next false unless key.start_with?(field)
          next true if key == field

          ransack_predicates.include?(key.delete_prefix("#{field}_"))
        end
      end

      def ransack_predicates
        @ransack_predicates ||= Ransack.predicates.keys.to_set
      end

      def invalid_filters(entry, keys)
        {
          error: "Unknown filter(s): #{keys.join(', ')}",
          filterable_fields: entry.filterable_fields,
          filterable_scopes: entry.filterable_scopes
        }
      end

      def forbidden(entry)
        { error: "You do not have permission to read #{entry.key}." }
      end

      # A resource reached only under a parent, or one whose controller
      # resolves its scope per request. Named rather than guessed at, because
      # a tool cannot invent the parent id such a path needs.
      def not_searchable(entry)
        {
          error: "#{entry.key} cannot be searched on its own.",
          available: ResourceMap.available_for(context).select(&:dispatchable?).map(&:key).sort
        }
      end
    end
  end
end
