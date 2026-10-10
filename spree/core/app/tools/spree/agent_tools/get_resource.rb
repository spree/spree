module Spree
  module AgentTools
    # Fetches one record in full, through the Admin API's own show operation,
    # for when the summary from a search is not enough to answer the question.
    class GetResource < Spree::AgentTool
      tool_name 'get_resource'
      description 'Fetch one record in full by its id, e.g. prod_86Rf07xd4z or an order number.'
      permission nil

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :id, description: 'The record id as shown in search results', required: true

      def call(resource:, id:)
        entry = ResourceMap.find(resource)
        return unknown_resource(resource) if entry.nil?
        return { error: "You do not have permission to read #{entry.key}." } unless
          context.permitted?(entry.permission)

        path = entry.api_path(:show)
        return { error: "#{entry.key} cannot be fetched one at a time." } if path.blank? || path.include?('/:') && path.count(':') > 1

        response = dispatch.call(method: :get, path: path.sub(':id', id.to_s))
        return { error: not_found(entry, id, response) } unless response.success?

        attributes = sanitize(response.data, entry)
        # An empty hash would be reported as a successful lookup of a record
        # with no fields, which is worse than saying the read failed.
        return { error: "Could not read this #{entry.key.singularize}." } if attributes.blank?

        {
          resource: entry.key,
          # The full record for the model to answer from, plus the same
          # compact row `search_resources` returns so the panel can show it
          # as something the merchant can click through to.
          record: attributes,
          records: [RecordSummary.from_payload(entry: entry, payload: attributes)],
          count: 1,
          total: 1
        }
      end

      # Named, not identified: "Look up Rotary Shaver 9000" is what the
      # merchant is watching happen. A prefixed id is our plumbing.
      def summary(arguments)
        "Look up #{arguments[:id]}"
      end

      private

      def dispatch
        @dispatch ||= ApiDispatch.new(context)
      end

      # Sanitized like every other outbound record: this is the one tool that
      # emits a whole serializer hash, so without the filter a serializer that
      # gains a token field would send it straight to the AI vendor — the
      # exact case the filter exists for.
      def sanitize(payload, entry)
        return {} unless payload.is_a?(Hash)

        RecordSummary.sanitize(payload.stringify_keys, entry.key)
      end

      # A record in another store and one that does not exist answer the same
      # way, so a probe learns nothing from the difference.
      def not_found(entry, id, response)
        return response.error_message if response.status != 404

        "No #{entry.key.singularize} found for #{id.inspect}"
      end
    end
  end
end
