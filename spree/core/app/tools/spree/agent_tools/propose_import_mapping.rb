module Spree
  module AgentTools
    # Applies a column mapping to an import, and starts it if the mapping is
    # complete.
    #
    # Mutating, and deliberately so. Mapping decides what every row in the
    # file becomes: get "Cost" onto `price` instead of `cost_price` and a
    # merchant has repriced their whole catalogue in one click. The merchant
    # sees the proposed pairing and approves it before anything is written.
    class ProposeImportMapping < Spree::AgentTools::ImportTool
      tool_name 'propose_import_mapping'
      description 'Map the columns of an uploaded import file onto Spree fields. ' \
                  'Call describe_import_mapping first to see the real column headings ' \
                  'and field names. Pass a mapping of spree_field => file_column; ' \
                  'omit a field to leave it unmapped. The merchant approves before ' \
                  'anything is applied.'
      # The Admin API gates every import action on the write scope of the
      # resource being imported — `write_products` for a product import —
      # never on a settings key. Mirrored here, per-import, in `call`.
      # Gated per import kind in `call`, not here: a caller who may import
      # customers but not products must still be offered the tool.
      permission nil
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
        unless context.holds?(required)
          return { error: "You do not have permission to run a #{import_kind(import)} import." }
        end

        refusal = unauthorized(:update, import)
        return refusal if refusal

        return { error: 'This import is not waiting to be mapped.' } unless import.mapping?

        pairs = sanitize(import, mapping)
        return unknown_fields(import, mapping) if pairs.empty?

        # A pair naming a field or column that does not exist is dropped here
        # rather than refusing the whole proposal — the valid half is usually
        # most of it, and a model that misspelled one heading should not have
        # to resend forty. It is named back, so the model can correct that one
        # and never believes it was applied.
        rejected = mapping.to_h.keys.map(&:to_s) - pairs.keys

        applied = apply!(import, pairs)
        start_if_ready(import)

        {
          ok: true,
          id: import.prefixed_id,
          # Only what was actually written. Reporting a field as mapped when
          # its mapping row did not exist would have the model tell the
          # merchant a column was handled when it was not.
          mapped: applied,
          # Named back so the model knows exactly what did not land, and why:
          # `rejected` did not exist on this import, `unmapped` exists but has
          # no mapping row to write to.
          rejected: rejected.presence,
          unmapped: (pairs.keys - applied.keys).presence,
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

      # Loaded in one query rather than one per field: a product import
      # declares forty-five of them, and a model proposing a full mapping
      # sends most at once.
      #
      # @return [Hash] only the pairs that had a mapping row to write to
      def apply!(import, pairs)
        rows = import.mappings.where(schema_field: pairs.keys).index_by(&:schema_field)
        applied = pairs.select { |field, _column| rows.key?(field) }

        Spree::ImportMapping.transaction do
          applied.each { |field, column| rows.fetch(field).update!(file_column: column) }
        end
        import.mappings.reload

        applied
      end

      # Starting the import is the same transition the dashboard's own mapping
      # step makes, and only once every required field is satisfied. Through
      # the workflow rather than the deprecated model method it replaced.
      def start_if_ready(import)
        return unless import.mapping_done?

        Spree.import_complete_mapping_workflow.call(import: import)
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
