module Spree
  module AgentTools
    # Tells the model which resources exist and what they can be filtered by,
    # so it discovers the real vocabulary instead of guessing field names and
    # producing errors the merchant has to read.
    class DescribeResource < Spree::AgentTool
      tool_name 'describe_resource'
      description 'List the store resources you can search, and the fields each one ' \
                  'can be filtered and sorted by. Call this before search_resources ' \
                  'if you are unsure which filter to use.'
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

        { resources: entries.map { |entry| describe(entry) } }
      end

      private

      def describe(entry)
        {
          resource: entry.key,
          filterable_fields: entry.filterable_fields,
          # Named queries answer things no column can — stock levels live
          # across warehouses, so "out of stock" is a scope, not a field.
          filterable_scopes: entry.filterable_scopes,
          usage: 'Attribute filters use Ransack predicates, e.g. name_cont, created_at_gteq, ' \
                 'status_eq. Named scopes are passed as a bare key set to true, e.g. ' \
                 '{"out_of_stock": true}.'
        }
      end
    end
  end
end
