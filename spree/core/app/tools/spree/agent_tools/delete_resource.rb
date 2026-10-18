module Spree
  module AgentTools
    # Removes a record, through the Admin API's own destroy operation —
    # which soft-deletes, archives or refuses exactly as the dashboard does.
    class DeleteResource < Spree::AgentTools::ResourceWrite
      tool_name 'delete_resource'
      description 'Delete a record. The endpoint decides what deleting means for it — some ' \
                  'resources archive, some refuse while they are in use.'

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :id, description: 'The record id as shown in search results', required: true

      def call(resource:, id:)
        entry, refusal = writable_entry(resource, :destroy)
        return refusal if refusal

        response = dispatch.call(method: :delete, path: entry.api_path(:destroy).sub(':id', id.to_s))
        return { error: response.error_message } unless response.success?

        { summary: summary(resource: resource, id: id) }
      end

      def summary(arguments)
        "Delete #{arguments[:resource].to_s.singularize.tr('_', ' ')} #{arguments[:id]}"
      end
    end
  end
end
