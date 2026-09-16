module Spree
  module AgentTools
    # Applies a column mapping to an import, and starts it if the mapping is
    # complete.
    #
    # Mutating, and deliberately so. Mapping decides what every row in the
    # file becomes: get "Cost" onto `price` instead of `cost_price` and a
    # merchant has repriced their whole catalogue in one click. The merchant
    # sees the proposed pairing and approves it before anything is written.
    class ProposeImportMapping < Spree::AgentTool
      tool_name 'propose_import_mapping'
      description 'Map the columns of an uploaded import file onto Spree fields. ' \
                  'Call describe_import_mapping first to see the real column headings ' \
                  'and field names. Pass a mapping of spree_field => file_column; ' \
                  'omit a field to leave it unmapped. The merchant approves before ' \
                  'anything is applied.'
      # The Admin API gates every import action on the write scope of the
      # resource being imported — `write_products` for a product import —
      # never on a settings key. Mirrored here, per-import, in `call`.
      permission 'write_products'
      mutating!

      param :id, description: 'Import id or number', required: true
      param :mapping, type: :object,
                      description: 'Spree field to file column, e.g. {"name": "Product Title"}',
                      required: true

      def call(id:, mapping:)
        import = find_import(id)
        return { error: "No import found for #{id.inspect}" } if import.nil?

        # Per-import, because a customer import needs `write_customers`
        # while a product import needs `write_products`.
        required = "write_#{import.class.required_scope}"
        unless context.permitted?(required)
          return { error: "You do not have permission to run a #{import_kind(import)} import." }
        end

        refusal = unauthorized(:update, import)
        return refusal if refusal

        return { error: 'This import is not waiting to be mapped.' } unless import.mapping?

        pairs = sanitize(import, mapping)
        return unknown_fields(import, mapping) if pairs.empty?

        apply!(import, pairs)
        start_if_ready(import)

        {
          ok: true,
          id: import.prefixed_id,
          mapped: pairs,
          status: import.reload.status,
          # `mapped_fields` returns mapping records, not names.
          still_missing: import.required_fields - import.mappings.mapped.pluck(:schema_field)
        }
      end

      # The merchant judges the pairing itself, so the card spells it out
      # rather than saying "apply a mapping".
      def summary(arguments)
        pairs = (arguments[:mapping] || {}).map { |field, column| "#{column} → #{field}" }
        return 'Apply an import mapping' if pairs.empty?

        "Map #{pairs.join(', ')}"
      end

      private

      def import_kind(import)
        import.class.name.demodulize.underscore.tr('_', ' ')
      end

      def find_import(id)
        scope = Spree::AgentTools::ResourceMap.find('imports').scope_for(context)

        scope.find_by_prefix_id(id) || scope.find_by(number: id)
      rescue ArgumentError, NoMethodError
        scope.find_by(number: id)
      end

      # Only fields the schema declares and columns the file actually has —
      # a hallucinated pairing must not reach the database.
      def sanitize(import, mapping)
        # `schema_fields` returns {name:, label:, required:} hashes, not names.
        fields = import.schema_fields.map { |field| field[:name].to_s }
        columns = import.csv_headers

        (mapping || {}).to_h.filter_map do |field, column|
          next unless fields.include?(field.to_s)
          next unless column.blank? || columns.include?(column.to_s)

          [field.to_s, column.presence&.to_s]
        end.to_h
      end

      def apply!(import, pairs)
        Spree::ImportMapping.transaction do
          pairs.each do |field, column|
            mapping = import.mappings.find_by(schema_field: field)
            next if mapping.nil?

            mapping.update!(file_column: column)
          end
        end
        import.mappings.reload
      end

      # Starting the import is the same transition the dashboard's own
      # mapping step makes, and only once every required field is satisfied.
      def start_if_ready(import)
        import.complete_mapping! if import.mapping_done?
      end

      def unknown_fields(import, mapping)
        {
          error: 'None of those fields or columns exist on this import.',
          spree_fields: import.schema_fields.map { |field| field[:name] },
          file_columns: import.csv_headers
        }
      end
    end
  end
end
