module Spree
  module AgentTools
    # Tells the model which resources exist and what they can be filtered by,
    # so it discovers the real vocabulary instead of guessing field names and
    # producing errors the merchant has to read.
    class DescribeResource < Spree::AgentTool
      tool_name 'describe_resource'
      description 'List the store resources you can search, the fields each one can be ' \
                  'filtered and sorted by, and what a write accepts. Describe one resource ' \
                  'for the full detail: what fits inside each list-valued attribute, and the ' \
                  'kinds a `type` field takes with each kind\'s preferences schema. Call this ' \
                  'before search_resources, create_resource or update_resource if unsure.'
      # Deliberately ungated: it exposes only field names, and the resources it
      # lists are already filtered to what this admin may read.
      permission nil

      param :resource,
            description: 'Optional resource key to describe. Omit to list them all.',
            required: false

      def call(resource: nil)
        entries = Spree::AgentTools::ResourceMap.available_for(context)
        entries = entries.select { |entry| entry.key == resource.to_s } if resource.present?

        if entries.empty?
          return { error: "Unknown or unavailable resource #{resource.inspect}",
                   available: Spree::AgentTools::ResourceMap.available_for(context).map(&:key) }
        end

        # One resource gets every type's schema; the listing names the types
        # only, because every family's schema at once is more than an index
        # should cost a model's context.
        { resources: entries.map { |entry| describe(entry, detailed: resource.present?) } }
      end

      private

      # The kinds a `type` takes, from the family's own registry — the same
      # list its `…/types` endpoint serves. An agent that never saw this list
      # guessed Ruby class names, and the write dropped every row.
      def types_for(family, detailed)
        return if family.nil?

        return family.api_types.sort unless detailed

        family.subclasses_with_preference_schema.map do |kind|
          kind.slice(:type, :label, :description, :schema).merge(calculators: calculators_for(family, kind[:type])).compact
        end
      rescue StandardError
        nil
      end

      # An action that prices its discount through a calculator takes one of
      # these, each with its own preferences — the same list as
      # `GET /promotion_actions/calculators`.
      def calculators_for(family, type)
        klass = family.find_by_api_type(type)
        return unless klass.respond_to?(:calculators)

        klass.calculators.map do |calculator|
          { type: calculator.api_type, label: calculator.description, schema: calculator.preference_json_schema }
        end.sort_by { |entry| entry[:label].to_s }.presence
      end

      def nested_types_for(entry, detailed)
        return if writable_attributes_for(entry).blank?

        entry.nested_typed_families.transform_values { |family| types_for(family, detailed) }.compact.presence
      end

      # Every dispatchable resource reports its attributes now: the generic
      # writes reach the controller, which runs whatever workflow it
      # declares, so there is no longer a class of resource they refuse.
      def nested_shapes_for(entry)
        return if writable_attributes_for(entry).blank?

        entry.nested_collection_shapes.presence
      end

      def writable_attributes_for(entry)
        return unless entry.api_path(:update).present? || entry.api_path(:create).present?
        return unless entry.write_permission.present? && context.permitted?(entry.write_permission)

        entry.writable_attribute_names.presence
      end

      def updatable_attributes_for(entry)
        writable = writable_attributes_for(entry)
        return if writable.nil?

        updatable = entry.writable_attribute_names(:update)
        updatable unless updatable == writable
      end

      # The action tools this caller is offered, by resource, worked out once
      # per call rather than once per resource described.
      def actions_for(entry)
        @actions ||= Spree.admin_agent_tools.to_a.grep(->(klass) { klass < Spree::AgentTools::OperationTool }).
                     select { |klass| context.permitted?(klass.permission) }.
                     group_by { |klass| klass.operation.resource_key }.
                     transform_values { |classes| classes.map(&:tool_name).sort }
        @actions[entry.key]
      end

      def describe(entry, detailed:)
        {
          resource: entry.key,
          # A resource reached through another record — an order's items, a
          # product's variants when written — needs that record's id as
          # parent_id on the calls whose route runs under it.
          parent: %i[index create update].lazy.filter_map { |action| entry.parent_key(action) }.first,
          filterable_fields: entry.filterable_fields,
          # What a generic write accepts, so the model learns the schema here
          # rather than by sending an invalid write and reading the refusal —
          # which is what create_resource and update_resource tell it to do.
          # Offered only where the caller could actually write.
          writable_attributes: writable_attributes_for(entry),
          # Where an update takes less than a create — an exchange's items
          # are fixed once it is opened — what update_resource accepts.
          updatable_attributes: updatable_attributes_for(entry),
          # The action tools that act on this resource — cancel, approve,
          # capture — so a model that found an order learns what it can do
          # to one without scanning the whole tool list.
          actions: actions_for(entry),
          # What goes inside a list-valued attribute. Without it a model sees
          # `variants` and has no idea a whole variant fits there, so it
          # creates the product and then adds each variant separately.
          nested_attributes: nested_shapes_for(entry),
          # The kinds this resource's own `type` takes (a payment method's
          # provider), and the kinds each nested row's `type` takes (a
          # promotion's rules and actions). The accepted values and their
          # preference schemas, so a model does not guess class names.
          types: types_for(entry.typed_family, detailed),
          nested_types: nested_types_for(entry, detailed),
          # What get_resource can be asked to include. A record arrives
          # without its associations, so a model that does not know these
          # names cannot ask for the one it needs.
          expandable_associations: entry.expandable_associations.presence,
          # The action tool for a record that has one of its own — cancel,
          # complete, approve. Ordinary attribute changes go through
          # update_resource whatever the controller does internally.
          created_by_tool: entry.create_workflow_key&.tr('.', '_'),
          updated_by_tool: entry.update_workflow_key&.tr('.', '_'),
          # Named queries answer things no column can — stock levels live
          # across warehouses, so "out of stock" is a scope, not a field.
          filterable_scopes: entry.filterable_scopes,
          usage: 'Attribute filters use Ransack predicates, e.g. name_cont, created_at_gteq, ' \
                 'status_eq. Named scopes are passed as a bare key set to true, e.g. ' \
                 '{"out_of_stock": true}. A type field takes one of the kinds under types or ' \
                 'nested_types, and a row\'s preferences follow that kind\'s schema.'
        }.compact
      end
    end
  end
end
