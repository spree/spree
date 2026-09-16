module Spree
  module AgentTools
    # Changes a record of a resource the Admin API writes directly.
    class UpdateResource < Spree::AgentTools::ResourceWrite
      tool_name 'update_resource'
      description 'Change a store setup record — a market, channel, delivery method, payment ' \
                  'method, tax rate and so on. Call describe_resource first for the attributes ' \
                  'a resource accepts. Catalog and order records are changed by their own tools.'

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :id, description: 'The record id as shown in search results', required: true
      param :attributes, type: :object, description: 'Attributes to change', required: true

      def call(resource:, id:, attributes: {})
        entry, refusal = writable_entry(resource)
        return refusal if refusal

        record = entry.scope_for(context, :update).find_by_prefix_id(id)
        return { error: "No #{entry.key.singularize} found for #{id.inspect}." } if record.nil?
        return { error: "You do not have permission to change this #{entry.key.singularize}." } unless context.can?(:update, record)

        permitted, rejection = permitted_attributes(entry, attributes)
        return rejection if rejection

        record.assign_attributes(permitted)
        save_record(entry, record)
      end
    end
  end
end
