module Spree
  module Api
    module OpenAPI
      # Turns one list endpoint's filter table into what a reader of the API
      # reference sees: `q[search]` and the other scopes as named query
      # parameters, and the attribute filters as a table rendered above the
      # endpoint (Mintlify's `x-mint.content`).
      class FilterDocumentation
        KIND_LABELS = {
          'text' => 'Text', 'decimal' => 'Amount', 'integer' => 'Number', 'date' => 'Date',
          'datetime' => 'Date and time', 'id' => 'Prefixed ID', 'type' => 'Type', 'boolean' => 'True or false'
        }.freeze

        SCOPE_SCHEMAS = {
          'boolean' => { type: :boolean }, 'integer' => { type: :integer }, 'decimal' => { type: :number }
        }.freeze

        # Raised when an endpoint offers `q[search]` and nothing says what it matches.
        class MissingSearchDescription < StandardError; end

        # @param endpoint [Spree::Api::V3::FilterTable::Endpoint]
        # @param querying_path [String] the docs page explaining predicates
        # @param search [String, nil] what `q[search]` matches, for a model
        #   whose search is not declared with `search_by`
        # @param scopes [Hash{String => String}] descriptions for other scopes
        def initialize(endpoint, querying_path:, search: nil, scopes: {})
          @endpoint = endpoint
          @table = endpoint.table
          @querying_path = querying_path
          @search = search
          @scopes = scopes.stringify_keys
        end

        # @return [Array<Hash>] rswag parameter definitions, `q[search]` first
        def parameters
          names = @table.scopes.keys.sort_by { |scope| scope == 'search' ? '' : scope }
          names.map { |scope| scope_parameter(scope, @table.scopes[scope]) }
        end

        # @return [String] MDX for the endpoint page
        def content
          lines = ['## Filters', '']
          lines << "Filter with `q[<attribute>_<predicate>]=value`, for example `#{example_key}`. Send a list as " \
                   "`q[<attribute>_in][]=a&q[<attribute>_in][]=b`. [How filters work](#{@querying_path})."
          lines << ''
          lines.concat(attribute_rows(@table))

          associations = association_rows
          if associations.any?
            lines << '' << '<Accordion title="Filters through associations">' << ''
            lines << 'Prefix an associated record\'s attribute with the association, as in ' \
                     "`q[#{associations.first[0]}id_eq]`. The same predicates apply." << ''
            lines << '| Prefix | Attributes |' << '|---|---|'
            associations.each { |prefix, attributes| lines << "| `#{prefix}` | #{attributes.map { |name| "`#{name}`" }.join(', ')} |" }
            lines << '' << '</Accordion>'
          end

          if @endpoint.to_h['custom_fields']
            lines << '' << "Also filters and sorts on the store's searchable custom fields, as " \
                           '`q[cf_<namespace>_<key>_<predicate>]` and `sort=cf_<namespace>_<key>`.'
          end

          sortable = @endpoint.sortable - @table.aliased_attributes
          if sortable.any?
            lines << '' << "**Sort by:** #{sortable.map { |field| "`#{field}`" }.join(', ')}. " \
                           'Prefix a field with `-` to sort descending.'
          end

          lines.join("\n")
        end

        private

        def scope_parameter(scope, type)
          list = type.is_a?(Hash) || type.is_a?(Array)
          {
            name: list ? "q[#{scope}][]" : "q[#{scope}]",
            in: :query,
            required: false,
            schema: scope_schema(type),
            description: scope == 'search' ? search_description : @scopes.fetch(scope) { default_scope_description(scope, type) }
          }
        end

        def scope_schema(type)
          case type
          when Hash then { type: :array, items: scope_schema(type['list']) }
          when Array then { type: :array, items: scope_schema(type.first), minItems: type.size, maxItems: type.size }
          else SCOPE_SCHEMAS.fetch(type, { type: :string })
          end
        end

        def search_description
          return @search if @search

          attributes = @table.model.search_attributes
          raise MissingSearchDescription, "#{@table.model.name}.search has no description; pass `search:` to filter_parameters_for" if attributes.empty?

          "Matches any of #{attributes.map { |path| path.tr('_', ' ') }.to_sentence} (partial, case-insensitive)."
        end

        def default_scope_description(scope, type)
          type == 'boolean' ? "Set to `true` to apply `#{scope}`." : "Applies `#{scope}` to the given value."
        end

        def attribute_rows(table)
          rows = ['| Attribute | Kind | Predicates |', '|---|---|---|']
          table.attributes.except(*table.aliased_attributes).each do |attribute, kind|
            label = kind.is_a?(Hash) ? "One of #{kind['enum'].map { |value| "`#{value}`" }.join(', ')}" : KIND_LABELS.fetch(kind)
            predicates = Spree::Api::V3::FilterPredicates::BY_KIND.fetch(kind.is_a?(Hash) ? 'enum' : kind)
            rows << "| `#{attribute}` | #{label} | #{predicates.map { |predicate| "`#{predicate}`" }.join(' ')} |"
          end
          rows
        end

        def association_rows
          visible = ->(table) { table.attributes.keys - table.aliased_attributes }
          @table.associations.flat_map do |name, associated|
            nested = associated.associations.reject { |_, table| table.model == @table.model }
            [["#{name}_", visible.(associated)]] + nested.map { |hop, table| ["#{name}_#{hop}_", visible.(table)] }
          end
        end

        def example_key
          texts = @table.attributes.select { |_, value| value == 'text' }
          attribute = (%w[number name code email] & texts.keys).first || texts.keys.first
          kind = 'text' if attribute
          attribute, kind = @table.attributes.first if attribute.nil?
          return 'q[id_eq]=…' if attribute.nil?

          kind == 'text' ? "q[#{attribute}_cont]=…" : "q[#{attribute}_eq]=…"
        end
      end
    end
  end
end
