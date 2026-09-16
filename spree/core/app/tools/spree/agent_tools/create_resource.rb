module Spree
  module AgentTools
    # Creates a record of a resource the Admin API writes directly.
    class CreateResource < Spree::AgentTools::ResourceWrite
      tool_name 'create_resource'
      description 'Create a store setup record — a market, channel, delivery method, payment ' \
                  'method, tax rate and so on. Call describe_resource first for the attributes ' \
                  'a resource accepts. Catalog and order records are created by their own tools.'

      param :resource, description: 'Resource key — call describe_resource for the list', required: true
      param :attributes, type: :object, description: 'Attributes to set on the new record', required: true

      def call(resource:, attributes: {})
        entry, refusal = writable_entry(resource)
        return refusal if refusal

        permitted, rejection = permitted_attributes(entry, attributes)
        return rejection if rejection

        record = build_record(entry, permitted)
        return { error: "You do not have permission to create this #{entry.key.singularize}." } unless context.can?(:create, record)

        save_record(entry, record)
      end

      protected

      def preferred_workflow_key(entry)
        entry.create_workflow_key.presence || entry.update_workflow_key
      end

      private

      # Built through the store's own association where there is one, so the
      # record carries its tenancy from where it was built rather than from an
      # attribute assigned afterwards — the same rule the API's build_resource
      # follows.
      def build_record(entry, attributes)
        association = entry.key.to_sym
        scope = context.store.respond_to?(association) ? context.store.public_send(association) : entry.model_class

        scope.new(attributes)
      end
    end
  end
end
