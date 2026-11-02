module Spree
  module AgentTools
    # Creates a record, through the Admin API's own create operation.
    class CreateResource < Spree::AgentTools::ResourceWrite
      tool_name 'create_resource'
      description 'Create a record — a product with its variants, an order with its line ' \
                  'items, a market, channel, payment method and so on. Send the whole record ' \
                  'in one call: a list-valued attribute takes complete rows, so a product\'s ' \
                  'variants carry their own options, prices and stock levels. Call ' \
                  'describe_resource first — its nested_attributes says what fits inside each ' \
                  'list. Records with an action of their own (cancelling, approving) have a ' \
                  'tool named for it.'

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :attributes, type: :object, description: 'Attributes to set on the new record', required: true
      param :parent_id, description: PARENT_ID_DESCRIPTION

      def call(resource:, attributes: {}, parent_id: nil)
        entry, refusal = writable_entry(resource, :create)
        return refusal if refusal

        body, rejection = body_for(entry, attributes)
        return rejection if rejection

        path, missing = write_path(entry, :create, parent_id: parent_id)
        return missing if missing

        response = dispatch.call(method: :post, path: path, body: body)

        result_for(response, entry, summary: summary(resource: resource, attributes: attributes))
      end

      def summary(arguments)
        named = arguments[:attributes].to_h.values_at('name', :name, 'number', :number).compact.first

        "Create #{arguments[:resource].to_s.singularize.tr('_', ' ')} #{named}".strip
      end
    end
  end
end
