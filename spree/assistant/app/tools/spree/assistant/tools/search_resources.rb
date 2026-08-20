module Spree
  module Assistant
    module Tools
      # Searches store records.
      #
      # Every lookup starts from the current store's own association and is
      # filtered through the model's Ransack allowlist, so the assistant can
      # reach exactly what the Admin API would let this admin reach — no more.
      class SearchResources < Spree::Assistant::Tool
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
          entry = Spree::Assistant::ResourceMap.find(resource)
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
          records = query.result.limit(capped_limit(limit)).to_a

          {
            resource: entry.key,
            # How many matched, not how many were returned. The assistant is
            # asked to say how many there are, so handing it the page size would
            # have it state "10 products" for a store holding hundreds.
            total: query.result.count,
            count: records.size,
            records: records.map { |record| Spree::Assistant::RecordSummary.call(entry: entry, record: record) }
          }
        end

        def summary(arguments)
          "Search #{arguments[:resource]}"
        end

        private

        def build_query(entry, filters, sort)
          query = entry.scope_for(context).ransack(filters)
          query.sorts = sort if sort.present?
          query
        end

        # A filter key is either a named scope (`out_of_stock`) or an
        # `<attribute>_<predicate>` pair, which Ransack accepts only if the
        # attribute is on the model's allowlist.
        def unrecognised_filters(entry, filters)
          allowed = entry.filterable_fields
          scopes = entry.filterable_scopes

          filters.keys.reject do |key|
            name = key.to_s
            scopes.include?(name) || allowed.any? { |field| name == field || name.start_with?("#{field}_") }
          end
        end

        def invalid_filters(entry, keys)
          {
            error: "Unknown filter(s): #{keys.join(', ')}",
            filterable_fields: entry.filterable_fields,
            filterable_scopes: entry.filterable_scopes
          }
        end

        # Ransack raises on unknown predicates, which is the behaviour we want —
        # but blank values silently match everything, so they are dropped.
        def sanitize_filters(filters)
          (filters || {}).to_h.compact_blank
        end

        def capped_limit(limit)
          return DEFAULT_LIMIT if limit.blank?

          [[limit.to_i, 1].max, MAX_LIMIT].min
        end

        def unknown_resource(resource)
          {
            error: "Unknown resource #{resource.inspect}",
            available: Spree::Assistant::ResourceMap.available_for(context).map(&:key)
          }
        end

        def forbidden(entry)
          { error: "You do not have permission to read #{entry.key}." }
        end
      end
    end
  end
end
