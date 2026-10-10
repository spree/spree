module Spree
  module AgentTools
    # Shared by the generic writes, which dispatch to the Admin API's own
    # create, update and destroy operations.
    #
    # The controller behind each decides everything that matters: which
    # attributes it accepts, whether it writes through a workflow, what the
    # refusal reads like. So these three are correct for every resource, and
    # the rule that a resource with a workflow refuses the generic write is
    # gone — there was only ever one way to write a record, and now these
    # take it.
    class ResourceWrite < Spree::AgentTool
      # Gated per resource in `call`, since each names its own write scope —
      # so the class declares none.
      permission nil
      mutating!

      # Offered only to a caller who can write something.
      #
      # The endpoint would refuse anyway, but a tool a credential can never
      # use should not be named to the model: the server promises that a tool
      # you cannot see is one the store has not granted.
      def permitted?
        ResourceMap.all.any? do |entry|
          entry.write_permission.present? && context.permitted?(entry.write_permission)
        end
      end

      protected

      def dispatch
        @dispatch ||= ApiDispatch.new(context)
      end

      # The entry, or the refusal naming why not.
      #
      # @return [Array(Entry, nil), Array(nil, Hash)]
      def writable_entry(key, action)
        entry = ResourceMap.find(key)
        return [nil, unknown_resource(key)] if entry.nil?

        path = entry.api_path(action)
        return [nil, { error: not_writable(entry, action) }] if path.blank?

        # The endpoint answers 403 for a scope the credential lacks, in its
        # own words. This check only avoids offering a tool that cannot work
        # — a resource the caller cannot even read.
        return [nil, { error: "You do not have permission to change #{entry.key}." }] unless
          context.permitted?(entry.permission)

        [entry, nil]
      end

      # Attributes travel as the request body, so what the controller accepts
      # is the only list — including the attributes an extension added, which
      # the hand-written list this replaces could not see.
      #
      # An attribute the controller does not permit is dropped silently and
      # the response is a 200, so a model would report a change that never
      # happened. Named back instead, the way an unknown filter is.
      #
      # @return [Array(Hash, nil), Array(nil, Hash)]
      def body_for(entry, attributes)
        body = (attributes || {}).to_h.deep_transform_keys(&:to_s)
        accepted = entry.writable_attribute_names
        return [body, nil] if accepted.blank?

        unknown = body.keys - accepted
        return [body, nil] if unknown.empty?

        [nil, { error: "#{entry.key} does not accept #{unknown.to_sentence}.",
                accepted_attributes: accepted }]
      end

      def result_for(response, entry, summary:)
        return { error: response.error_message } unless response.success?

        payload = response.data
        record = payload.is_a?(Hash) ? RecordSummary.sanitize(payload.stringify_keys, entry.key) : nil

        {
          summary: summary,
          record: record && RecordSummary.from_payload(entry: entry, payload: record)
        }.compact
      end

      def not_writable(entry, action)
        verb = { create: 'created', update: 'updated', destroy: 'deleted' }.fetch(action, 'changed')

        "#{entry.key} cannot be #{verb} this way — call describe_resource to see what can."
      end
    end
  end
end
