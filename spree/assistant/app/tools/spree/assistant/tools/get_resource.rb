module Spree
  module Assistant
    module Tools
      # Fetches one record in full, for when the summary from a search is not
      # enough to answer the question.
      class GetResource < Spree::Assistant::Tool
        tool_name 'get_resource'
        description 'Fetch one record in full by its id, e.g. prod_86Rf07xd4z or an order number.'
        permission nil

        param :resource, description: 'One of: products, orders, promotions, categories', required: true
        param :id, description: 'The record id as shown in search results', required: true

        def call(resource:, id:)
          entry = Spree::Assistant::ResourceMap.find(resource)
          return { error: "Unknown resource #{resource.inspect}" } if entry.nil?
          return { error: "You do not have permission to read #{entry.key}." } unless context.permitted?(entry.permission)

          record = find_record(entry, id)
          return { error: "No #{entry.key.singularize} found for #{id.inspect}" } if record.nil?

          { resource: entry.key, record: entry.serializer_class.new(record).to_h }
        end

        def summary(arguments)
          "Look up #{arguments[:resource]} #{arguments[:id]}"
        end

        private

        # Scoped through the store, so an id belonging to another store is a
        # miss rather than a leak.
        def find_record(entry, id)
          scope = entry.scope_for(context.store)

          scope.find_by_prefix_id(id) || find_by_natural_key(scope, id)
        rescue StandardError
          find_by_natural_key(scope, id)
        end

        # Merchants say order numbers and product slugs out loud far more often
        # than prefixed ids, and the model repeats what the merchant said.
        def find_by_natural_key(scope, id)
          %i[number slug].each do |column|
            next unless scope.klass.column_names.include?(column.to_s)

            record = scope.find_by(column => id)
            return record if record
          end

          nil
        end
      end
    end
  end
end
