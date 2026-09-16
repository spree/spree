module Spree
  module AgentTools
    # Searches store records.
    #
    # Every lookup starts from the current store's own association and is
    # filtered through the model's Ransack allowlist, so the assistant can
    # reach exactly what the Admin API would let this admin reach — no more.
    class SearchResources < Spree::AgentTool
      DEFAULT_LIMIT = 10
      MAX_LIMIT = 25

      tool_name 'search_resources'
      description 'Search the store. Filters are Ransack predicates ' \
                  '(name_cont, created_at_gteq, status_eq) or named scopes passed as a ' \
                  'bare key, e.g. {"out_of_stock": true} for stock questions or ' \
                  '{"price_lte": 20} for price. Call describe_resource to see every ' \
                  'resource, field and scope available.'
      # Per-resource permissions are enforced per call — this tool is offered
      # whenever the admin can read anything at all.
      permission nil

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :filters, type: :object, description: 'Ransack filter hash, e.g. {"name_cont": "shirt"}'
      param :sort, description: 'Sort, e.g. "created_at desc"'
      param :limit, type: :integer, description: "Max records to return (default #{DEFAULT_LIMIT})"

      def call(resource:, filters: nil, sort: nil, limit: nil)
        entry = Spree::AgentTools::ResourceMap.find(resource)
        return unknown_resource(resource) if entry.nil?
        return forbidden(entry) unless context.permitted?(entry.permission)

        applied = sanitize_filters(filters)
        # Ransack silently drops filters it does not recognise, so an invented
        # field would quietly widen the search to everything and the assistant
        # would report the result as a match. Reject it instead, and say which
        # fields exist so the model can correct itself.
        unrecognised = unrecognised_filters(entry, applied)
        return invalid_filters(entry, unrecognised) if unrecognised.any?

        query = build_query(entry, applied, sort)
        # `accessible_by` builds LEFT JOINs for an association condition
        # (`can :read, Product, categories: {...}`), so without `distinct` a
        # record repeats once per matching row and the count is inflated —
        # and the assistant states that count as fact.
        result = query.result.distinct
        records = result.limit(capped_limit(limit)).to_a

        {
          resource: entry.key,
          # How many matched, not how many were returned. The assistant is
          # asked to say how many there are, so handing it the page size would
          # have it state "10 products" for a store holding hundreds.
          total: result.count,
          count: records.size,
          records: records.map { |record| Spree::AgentTools::RecordSummary.call(entry: entry, record: record) }
        }
      end

      def summary(arguments)
        label = arguments[:resource].to_s.tr('_', ' ')
        filters = arguments[:filters]
        return "Search #{label}" if filters.blank?

        # Name the filter in words, so the activity line says what is being
        # looked for rather than only where.
        described = filters.keys.map { |key| key.to_s.tr('_', ' ') }.join(', ')
        "Search #{label} by #{described}"
      end

      private

      # Preloaded the way the admin controllers preload: the summary row runs
      # the resource's own serializer, whose associations would otherwise be
      # one query per record.
      def searchable_scope(entry)
        scope = entry.scope_for(context)
        scope.respond_to?(:preload_associations_lazily) ? scope.preload_associations_lazily : scope
      end

      def build_query(entry, filters, sort)
        query = searchable_scope(entry).ransack(filters)
        query.sorts = sort if sort.present?
        query
      end

      # A filter key is either a named scope (`out_of_stock`) or an
      # `<attribute>_<predicate>` pair. BOTH halves must be checked: Ransack
      # runs with `ignore_unknown_conditions` on, so it silently drops a key
      # it cannot parse and returns the whole collection — which the
      # assistant then reports as the answer ("you have 38 products with
      # status notreal"). Checking only the attribute prefix let exactly that
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
          # A bare attribute means Ransack's default `eq`.
          next true if key == field

          predicate = key.delete_prefix("#{field}_")
          ransack_predicates.include?(predicate)
        end
      end

      # Every predicate Ransack knows, including the compound `_any`/`_all`
      # suffixes it generates.
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

      # Empty values match everything, so they are dropped — but `false` is a
      # real filter value (`{"out_of_stock": false}`), and `compact_blank`
      # would have thrown it away and quietly returned the whole collection.
      def sanitize_filters(filters)
        (filters || {}).to_h.reject { |_key, value| value.nil? || value == '' }
      end

      def capped_limit(limit)
        return DEFAULT_LIMIT if limit.blank?

        [[limit.to_i, 1].max, MAX_LIMIT].min
      end

      def unknown_resource(resource)
        {
          error: "Unknown resource #{resource.inspect}",
          available: Spree::AgentTools::ResourceMap.available_for(context).map(&:key)
        }
      end

      def forbidden(entry)
        { error: "You do not have permission to read #{entry.key}." }
      end
    end
  end
end
