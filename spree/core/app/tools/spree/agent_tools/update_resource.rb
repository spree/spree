module Spree
  module AgentTools
    # Changes a record, through the Admin API's own update operation — which
    # runs whatever workflow the controller declares, so this is the same
    # write the dashboard performs.
    class UpdateResource < Spree::AgentTools::ResourceWrite
      tool_name 'update_resource'
      description 'Change a record. Call describe_resource first for the attributes a ' \
                  'resource accepts, and send only the ones to change.'

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :id, description: 'The record id as shown in search results', required: true
      param :attributes, type: :object, description: 'Attributes to change', required: true

      def call(resource:, id:, attributes: {})
        entry, refusal = writable_entry(resource, :update)
        return refusal if refusal

        body, rejection = body_for(entry, attributes)
        return rejection if rejection

        response = dispatch.call(
          method: :patch,
          path: entry.api_path(:update).sub(':id', id.to_s),
          body: body
        )

        result_for(response, entry, summary: summary(resource: resource, id: id, attributes: attributes))
      end

      def summary(arguments)
        changed = arguments[:attributes].to_h.keys.map { |key| key.to_s.tr('_', ' ') }

        "Update #{arguments[:resource].to_s.singularize.tr('_', ' ')} #{arguments[:id]}" \
          "#{": #{changed.to_sentence}" if changed.any?}"
      end
    end
  end
end
