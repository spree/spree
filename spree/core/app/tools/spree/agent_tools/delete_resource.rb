module Spree
  module AgentTools
    # Removes a record of a resource the Admin API deletes directly.
    class DeleteResource < Spree::AgentTools::ResourceWrite
      tool_name 'delete_resource'
      description 'Delete a store setup record. Catalog and order records are removed by their ' \
                  'own tools, which run the workflow the dashboard runs.'

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :id, description: 'The record id as shown in search results', required: true

      def call(resource:, id:)
        entry, refusal = writable_entry(resource)
        return refusal if refusal

        record = entry.scope_for(context, :destroy).find_by_prefix_id(id)
        return { error: "No #{entry.key.singularize} found for #{id.inspect}." } if record.nil?
        return { error: "You do not have permission to delete this #{entry.key.singularize}." } unless context.can?(:destroy, record)

        label = RecordSummary.call(entry: entry, record: record)[:title]

        if record.destroy
          { summary: "Delete #{entry.key.singularize.humanize.downcase} #{label}" }
        else
          { error: record.errors.full_messages.to_sentence.presence || "#{label} could not be deleted." }
        end
      end
    end
  end
end
