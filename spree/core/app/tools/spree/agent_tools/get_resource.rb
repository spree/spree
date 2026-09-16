module Spree
  module AgentTools
    # Fetches one record in full, for when the summary from a search is not
    # enough to answer the question.
    class GetResource < Spree::AgentTool
      tool_name 'get_resource'
      description 'Fetch one record in full by its id, e.g. prod_86Rf07xd4z or an order number.'
      permission nil

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :id, description: 'The record id as shown in search results', required: true

      def call(resource:, id:)
        entry = Spree::AgentTools::ResourceMap.find(resource)
        return { error: "Unknown resource #{resource.inspect}" } if entry.nil?
        return { error: "You do not have permission to read #{entry.key}." } unless context.permitted?(entry.permission)

        record = find_record(entry, id)
        return { error: "No #{entry.key.singularize} found for #{id.inspect}" } if record.nil?

        attributes = serialize(entry, record)

        {
          resource: entry.key,
          # The full record for the model to answer from, plus the same
          # compact row `search_resources` returns so the panel can show it
          # as something the merchant can click through to.
          #
          # Sanitized like every other outbound record: this is the one tool
          # that emits a whole serializer hash, so without the filter a
          # serializer that gains a token field would send it straight to the
          # AI vendor — the exact case the filter exists for.
          record: attributes,
          records: [Spree::AgentTools::RecordSummary.call(entry: entry, record: record, attributes: attributes)],
          count: 1,
          total: 1
        }
      end

      # Named, not identified: "Look up Rotary Shaver 9000" is what the
      # merchant is watching happen. A prefixed id is our plumbing.
      def summary(arguments)
        entry = Spree::AgentTools::ResourceMap.find(arguments[:resource])
        record = entry && find_record(entry, arguments[:id])
        label = record && Spree::AgentTools::RecordSummary.call(entry: entry, record: record)[:title]

        "Look up #{label.presence || arguments[:id]}"
      rescue StandardError
        "Look up #{arguments[:resource]}"
      end

      private

      # A serializer that raises on one record must be a tool error the model
      # can act on, not a protocol failure — the same guard RecordSummary
      # applies to the summary row.
      def serialize(entry, record)
        Spree::AgentTools::RecordSummary.sanitize(entry.serializer_class.new(record).to_h)
      rescue StandardError => e
        Rails.logger.warn("[Spree] #{entry.key} serializer failed: #{e.class}: #{e.message}")
        {}
      end

      # Scoped through the store, so an id belonging to another store is a
      # miss rather than a leak.
      def find_record(entry, id)
        scope = entry.scope_for(context)

        by_prefixed_id(scope, id) || find_by_natural_key(scope, id)
      end

      # Only the prefixed-id decode is expected to fail here — the model may
      # pass a slug or an order number. Guarded around that call alone, so a
      # failure further along is not swallowed into a confusing nil.
      def by_prefixed_id(scope, id)
        scope.find_by_prefix_id(id)
      rescue ArgumentError, NoMethodError
        nil
      end

      # Merchants say order numbers and product slugs out loud far more often
      # than prefixed ids, and the model repeats what the merchant said.
      def find_by_natural_key(scope, id)
        %i[number slug].each do |column|
          next unless scope.klass.column_names.include?(column.to_s)

          record = scope.find_by(column => id)
          return record if record
        end

        nil
      end
    end
  end
end
