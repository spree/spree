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

          records = search(entry, filters, sort, limit)

          {
            resource: entry.key,
            count: records.size,
            records: records.map { |record| summarize(entry, record) }
          }
        rescue StandardError => e
          # A bad filter is the model's mistake to correct, not a dead turn.
          { error: e.message, hint: 'Call describe_resource to see valid fields.' }
        end

        def summary(arguments)
          "Search #{arguments[:resource]}"
        end

        private

        def search(entry, filters, sort, limit)
          query = entry.scope_for(context.store).ransack(sanitize_filters(filters))
          query.sorts = sort if sort.present?

          query.result.limit(capped_limit(limit)).to_a
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

        # A compact, model-readable row. Prefixed ids only, so anything the
        # assistant repeats back is a valid dashboard link.
        def summarize(entry, record)
          serializer = entry.serializer_class.new(record)
          attributes = serializer.to_h

          attributes.slice(*summary_keys(attributes)).merge(id: record.prefixed_id)
        rescue StandardError
          { id: record.prefixed_id, label: record.try(:name) || record.try(:number) || record.to_s }
        end

        SUMMARY_KEYS = %w[
          id name slug number status email total display_total currency
          created_at completed_at available_on price display_price
        ].freeze

        def summary_keys(attributes)
          SUMMARY_KEYS.select { |key| attributes.key?(key) }
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
