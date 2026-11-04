module Spree
  module AgentTools
    # One agent tool per Admin API operation in {OperationCatalog}.
    #
    # Everything about the tool is the operation's: its name, its prose, its
    # arguments and the request it sends. The arguments are the path segments
    # and the request body under the names the document gives them, so a call
    # is a request with no translation step between what the model was shown
    # and what the endpoint receives. The endpoint runs its own routing,
    # authentication, scope check, record-level ability and workflow.
    #
    # Generated classes are cached per entry, so a catalog rebuilt after a
    # code reload produces new tools rather than serving stale ones.
    #
    # See docs/plans/6.0-agent-tools-from-openapi.md.
    class OperationTool < Spree::AgentTool
      class_attribute :operation, instance_accessor: false

      class << self
        # @param entry [OperationCatalog::Entry]
        # @return [Class<OperationTool>]
        def for(entry)
          # By identity: an entry is rebuilt, as a new object, whenever the
          # catalog is, and hashing one walks its whole request schema.
          cache[entry] ||= Class.new(self) do
            self.operation = entry

            tool_name entry.name
            description entry.description
            permission entry.permission
            mutating! if entry.mutating
          end
        end

        # @return [Hash] JSON Schema for the arguments, read by the adapters
        def input_schema
          @input_schema ||= operation.input_schema
        end

        # @return [void]
        def clear_cache!
          @cache = {}
        end

        private

        def cache
          @cache ||= {}.compare_by_identity
        end
      end

      delegate :operation, to: :class

      # @return [Hash] the result handed back to the model
      def call(**arguments)
        arguments, notes = map_legacy_arguments(arguments.transform_keys(&:to_s))

        segments = operation.path_params.index_with { |segment| arguments[segment] }
        derive_parents(segments)
        path = operation.path_for(segments)
        # Only what the path needs is checked here. What the body requires is
        # the endpoint's to refuse, in its own words.
        if path.nil?
          unfilled = segments.select { |_segment, value| value.blank? }.keys
          return { error: "#{tool_name} needs #{unfilled.to_sentence}.", deprecations: notes.presence }.compact
        end

        values, refusal = body_for(arguments)
        return refusal.merge(deprecations: notes.presence).compact if refusal

        response = dispatch(path, values)
        return { error: response.error_message, deprecations: notes.presence }.compact unless response.success?

        # A read opted in to the catalog answers with what it read, filtered
        # like every other record that leaves for a model.
        return { summary: operation.summary, data: sanitized(response.data) } if operation.read?

        record = payload_summary(response.data)
        named = record&.dig(:title).presence || record&.dig(:id).presence || record&.dig('id').presence
        { summary: named ? "#{operation.summary} #{named}" : summary(arguments), record: record,
          deprecations: notes.presence }.compact
      end

      # The line a client shows before the call runs: the operation's own
      # summary and the records it names.
      #
      # @param arguments [Hash]
      # @return [String]
      def summary(arguments)
        arguments, = map_legacy_arguments(arguments.transform_keys(&:to_s))
        named = operation.path_params.filter_map { |segment| arguments[segment] }
        [operation.summary, named.reverse.join(' ').presence].compact.join(' ')
      end

      private

      # 6.0.0 names (`order`, `reason`) mapped to the operation's (`id`,
      # `cancel_reason_id`), with a note per name so the model learns the new
      # one. A name the endpoint never read is dropped and said to be.
      def map_legacy_arguments(arguments)
        renames = operation.legacy_parameters
        return [arguments, []] if renames.blank?

        notes = []
        mapped = arguments.each_with_object({}) do |(name, value), result|
          next result[name] = value unless renames.key?(name)

          target = renames[name]
          if target == :merge && value.is_a?(Hash)
            notes << "#{name} is deprecated: send its fields as arguments of their own."
            result.merge!(value.transform_keys(&:to_s)) { |_key, given, _merged| given }
          elsif target.nil? || target == :merge
            notes << "#{name} is not something #{tool_name} sets, and was ignored."
          else
            notes << "#{name} is deprecated: use #{target}."
            result[target] = value unless result.key?(target)
          end
        end

        [mapped, notes]
      end

      # A parent segment the caller left out, read off a record the call
      # does name — a payment's order, a fulfillment's order — through the
      # resource map, under the caller's store. Only a record the caller may
      # read is consulted; anything else stays unfilled and is asked for.
      def derive_parents(segments)
        missing = operation.parent_keys.keys.select { |segment| segments[segment].blank? }
        return if missing.empty?

        records = segments.compact_blank.to_a.reverse.filter_map { |segment, id| record_for(segment, id) }
        missing.reverse_each do |segment|
          parent = records.lazy.filter_map { |record| record.try(segment.delete_suffix('_id')) }.first
          next if parent.nil?

          segments[segment] = parent.try(:prefixed_id)
          records << parent
        end
      end

      def record_for(segment, id)
        key = segment == 'id' ? operation.resource_key : operation.segment_keys[segment]
        entry = key && ResourceMap.find(key)
        return if entry.nil? || !context.permitted?(entry.permission)

        entry.scope_for(context).find_by_prefix_id(id)
      rescue StandardError
        nil
      end

      def dispatch(path, values)
        dispatcher = ApiDispatch.new(context)
        return dispatcher.call(method: :get, path: path, params: values || {}) if operation.read?

        dispatcher.call(method: operation.verb.to_sym, path: path, body: values)
      end

      # What travels as the body, or a read's query: every argument that is
      # not a path segment, checked against the document so a guessed field is
      # named back rather than dropped behind a success.
      def body_for(arguments)
        body = arguments.except(*operation.path_params)
        return [nil, nil] if body.empty?

        accepted = operation.body_properties.keys
        unknown = body.keys - accepted
        return [body, nil] if unknown.empty?

        [nil, { error: "#{tool_name} does not accept #{unknown.to_sentence}.",
                accepted_arguments: (operation.path_params + accepted).sort }]
      end

      # The record the endpoint returned, compacted and filtered the way a
      # record read from the map is.
      def payload_summary(data)
        return unless data.is_a?(Hash)

        entry = operation.resource_key && ResourceMap.find(operation.resource_key)
        return sanitized(data).slice('id').presence if entry.nil?

        RecordSummary.from_payload(entry: entry, payload: data)
      end

      def sanitized(data)
        RecordSummary.sanitize(data, operation.resource_key)
      end
    end
  end
end
