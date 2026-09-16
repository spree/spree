module Spree
  module AgentTools
    # What an import still needs mapped: the file's own column headings, the
    # Spree fields available, and which of those are required.
    #
    # This is the half of the mapping problem a computer cannot do. Deciding
    # that a column headed "Retail Price (inc VAT)" is the price field is
    # judgement about messy human spreadsheets — exactly what the model is
    # for — but it can only judge from the real vocabulary, so this hands it
    # the schema rather than letting it guess field names.
    class DescribeImportMapping < Spree::AgentTool
      tool_name 'describe_import_mapping'
      description "List an import's unmapped file columns and the Spree fields they can " \
                  'map onto, so you can propose a mapping. Call this before ' \
                  'propose_import_mapping.'
      permission 'read_settings'

      param :id, description: 'Import id or number. Omit for the most recent import awaiting mapping.',
                 required: false

      def call(id: nil)
        import = find_import(id)
        return { error: 'No import is waiting to be mapped.' } if import.nil?

        {
          id: import.prefixed_id,
          number: import.number,
          status: import.status,
          file_columns: import.csv_headers,
          unmapped_file_columns: import.unmapped_file_columns,
          spree_fields: describe_fields(import),
          already_mapped: current_mapping(import),
          sample_row: import.sample_row
        }.compact
      end

      def summary(arguments)
        'Read the import file layout'
      end

      private

      def find_import(id)
        scope = Spree::AgentTools::ResourceMap.find('imports').scope_for(context)
        return scope.where(status: 'mapping').order(created_at: :desc).first if id.blank?

        scope.find_by_prefix_id(id) || scope.find_by(number: id)
      rescue ArgumentError, NoMethodError
        scope.find_by(number: id)
      end

      # Name, human label and whether it must be filled — the model needs all
      # three to explain its choices and to know what it cannot leave out.
      #
      # Read from `schema_fields`, which is what a mapping is validated
      # against: it adds the model's custom-field definitions to the schema's
      # own list. Describing the schema alone would accept a custom field on
      # write while never telling the model it exists.
      def describe_fields(import)
        Array(import.schema_fields).map do |field|
          {
            field: field[:name],
            label: field[:label],
            required: field[:required] == true
          }
        end
      end

      def current_mapping(import)
        mapped = import.mappings.mapped
        return if mapped.empty?

        mapped.to_h { |mapping| [mapping.schema_field, mapping.file_column] }
      end
    end
  end
end
