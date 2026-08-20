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
        description 'Search the store for records: products, orders, promotions or categories. ' \
                    'Filters use Ransack predicates (name_cont, created_at_gteq, status_eq). ' \
                    'Use describe_resource first if unsure which fields exist.'
        # Per-resource permissions are enforced per call — this tool is offered
        # whenever the admin can read anything at all.
        permission nil

        param :resource, description: 'One of: products, orders, promotions, categories', required: true
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

          records = search(entry, applied, sort, limit)

          {
            resource: entry.key,
            count: records.size,
            records: records.map { |record| Spree::Assistant::RecordSummary.call(entry: entry, record: record) }
          }
        end

        def summary(arguments)
          "Search #{arguments[:resource]}"
        end

        private

        def search(entry, filters, sort, limit)
          query = entry.scope_for(context.store).ransack(filters)
          query.sorts = sort if sort.present?

          query.result.limit(capped_limit(limit)).to_a
        end

        # A filter key is `<attribute>_<predicate>`; Ransack accepts it only if
        # the attribute is on the model's allowlist. Matching the longest
        # attribute first keeps names containing underscores intact.
        def unrecognised_filters(entry, filters)
          allowed = entry.filterable_fields

          filters.keys.reject do |key|
            allowed.any? { |field| key.to_s == field || key.to_s.start_with?("#{field}_") }
          end
        end

        def invalid_filters(entry, keys)
          {
            error: "Unknown filter(s): #{keys.join(', ')}",
            filterable_fields: entry.filterable_fields
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
