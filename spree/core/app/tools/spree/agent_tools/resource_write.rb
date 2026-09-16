module Spree
  module AgentTools
    # Shared behaviour for the generic record writes.
    #
    # These exist only for resources whose controller saves the record
    # directly — store, market, channel, delivery, payment and tax setup. A
    # resource written through a workflow refuses them and names its workflow
    # tool instead, so there is exactly one way to write each thing and every
    # write goes through the same validations, hooks and events the dashboard
    # fires.
    class ResourceWrite < Spree::AgentTool
      mutating!

      # Ungated at the class level because the gate is per resource: a key with
      # `write_settings` may update a market but not a seller, and the resource
      # is not known until the call. {#call} checks the entry's own write
      # permission, and {#permitted?} offers the tool to anyone holding any
      # write key at all.
      permission nil

      # Offered only to a caller who may write something, so a read-only key
      # is never told these tools exist.
      #
      # @return [Boolean]
      def permitted?
        ResourceMap.all.any? { |entry| writable_for?(entry) }
      end

      protected

      # Resolves the resource and refuses, in the model's own vocabulary, when
      # it cannot be written generically.
      #
      # @param key [String]
      # @return [Array(ResourceMap::Entry, nil), Array(nil, Hash)]
      def writable_entry(key)
        entry = ResourceMap.find(key)
        return [nil, { error: "Unknown resource #{key.inspect}." }] if entry.nil?

        unless entry.generic_writes?
          return [nil, { error: refusal_for(entry) }]
        end

        unless context.permitted?(entry.write_permission)
          return [nil, { error: "You do not have permission to change #{entry.key}." }]
        end

        [entry, nil]
      end

      # A resource with a workflow is not written here — the tool that does it
      # is named, so the model retries correctly instead of giving up. Which
      # tool depends on what was asked for: creating names the create
      # workflow, changing and deleting name the update one.
      def refusal_for(entry)
        workflow_key = preferred_workflow_key(entry)

        if workflow_key.blank?
          return "#{entry.key} cannot be written with this tool — it is managed elsewhere in the dashboard."
        end

        "#{entry.key} is written through a workflow — use the #{workflow_key.tr('.', '_')} tool instead."
      end

      # Overridden by CreateResource, which wants the create workflow named.
      def preferred_workflow_key(entry)
        entry.update_workflow_key.presence || entry.create_workflow_key
      end

      # Only the attributes the Admin API itself would accept. Anything else is
      # named back rather than silently dropped, so a model that guessed a
      # field name learns the real one from `describe_resource`.
      #
      # @return [Array(Hash, nil), Array(nil, Hash)]
      def permitted_attributes(entry, attributes)
        attributes = (attributes || {}).transform_keys(&:to_s)
        allowed = entry.writable_attribute_names
        rejected = attributes.keys - allowed

        if rejected.any?
          return [nil, { error: "#{entry.key} does not accept #{rejected.to_sentence}. " \
                                "Accepted attributes: #{allowed.to_sentence}." }]
        end

        [attributes, nil]
      end

      # Saves through the model's own validations, and hands their messages
      # back verbatim when it refuses.
      def save_record(entry, record)
        return { error: record.errors.full_messages.to_sentence } unless record.save

        # One serialization: the summary line needs the record's title, which
        # is what the summary row already carries.
        row = RecordSummary.call(entry: entry, record: record)

        { summary: summary_for(entry, row[:title]), record: row }
      end

      def summary_for(entry, label)
        "#{self.class.tool_name.humanize} #{entry.key.singularize.humanize.downcase} #{label}"
      end

      private

      def writable_for?(entry)
        entry.generic_writes? && context.permitted?(entry.write_permission)
      end
    end
  end
end
