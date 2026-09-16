module Spree
  module AgentTools
    # Where an import has got to, and what went wrong with it.
    #
    # A merchant who uploaded a file wants one of two answers: is it done, or
    # why did those rows fail? Both are tedious to assemble from the imports
    # page and easy to say in a sentence.
    class GetImportStatus < Spree::AgentTool
      FAILED_ROW_SAMPLE = 5

      tool_name 'get_import_status'
      description 'Check how an import is going: its state, how many rows succeeded ' \
                  'or failed, and why the failures failed.'
      permission 'read_settings'

      param :id, description: 'Import id or number. Omit for the most recent import.',
                 required: false

      def call(id: nil)
        import = find_import(id)
        return { error: 'No import found.' } if import.nil?

        {
          id: import.prefixed_id,
          number: import.number,
          type: import_kind(import),
          status: import.status,
          rows: import.rows_status_counts,
          # The reasons, not the rows: a merchant fixes a spreadsheet by
          # learning "12 rows have no SKU", not by reading 12 rows back.
          failure_reasons: failure_reasons(import)
        }.compact
      end

      def summary(arguments)
        arguments[:id].present? ? "Check import #{arguments[:id]}" : 'Check the latest import'
      end

      private

      def find_import(id)
        scope = Spree::AgentTools::ResourceMap.find('imports').scope_for(context)
        return scope.order(created_at: :desc).first if id.blank?

        scope.find_by_prefix_id(id) || scope.find_by(number: id)
      rescue ArgumentError, NoMethodError
        scope.find_by(number: id)
      end

      def import_kind(import)
        import.class.name.demodulize.underscore
      end

      # Grouped so the assistant can say "12 rows failed because the SKU was
      # missing" rather than reciting every row.
      def failure_reasons(import)
        failed = import.rows.failed.limit(200)
        return if failed.empty?

        failed.filter_map { |row| row.validation_errors.presence }
              .tally
              .sort_by { |_reason, count| -count }
              .first(FAILED_ROW_SAMPLE)
              .map { |reason, count| { reason: reason, rows: count } }
      end
    end
  end
end
