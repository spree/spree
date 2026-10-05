module Spree
  module AgentTools
    # Where an import has got to, and what went wrong with it.
    #
    # A merchant who uploaded a file wants one of two answers: is it done, or
    # why did those rows fail? Both are tedious to assemble from the imports
    # page and easy to say in a sentence.
    class GetImportStatus < Spree::AgentTools::ImportTool
      # How many failed rows are read to work out why they failed.
      SCANNED_ROW_LIMIT = 200
      FAILED_ROW_SAMPLE = 5

      tool_name 'get_import_status'
      description 'Check how an import is going: its state, how many rows succeeded ' \
                  'or failed, and why the failures failed.'
      # Gated per import in `call`, on the scope of the resource being
      # imported: the failed rows carry the uploaded data.
      permission nil

      param :id, description: 'Import id or number. Omit for the most recent import.',
                 required: false

      def call(id: nil)
        import = find_import(id)
        return { error: 'No import found.' } if import.nil?

        refusal = unauthorized_import(import)
        return refusal if refusal

        {
          id: import.prefixed_id,
          number: import.number,
          type: import_kind(import),
          status: import.status,
          rows: import.rows_status_counts,
          # The reasons, not the rows: a merchant fixes a spreadsheet by
          # learning "12 rows have no SKU", not by reading 12 rows back.
          #
          # Gated on the write scope rather than the read one, because a
          # validation message quotes the value that failed ("Sku 'X' has
          # already been taken") — so it can carry uploaded data that was
          # never persisted, which reading the resource does not cover.
          failure_reasons: (failure_reasons(import) if may_read_failures?(import))
        }.compact
      end

      def summary(arguments)
        arguments[:id].present? ? "Check import #{arguments[:id]}" : 'Check the latest import'
      end

      private

      # @return [Boolean]
      def may_read_failures?(import)
        scope = import.class.try(:required_scope)
        return true if scope.blank?

        context.holds?("write_#{scope}")
      end

      # Grouped so the assistant can say "12 rows failed because the SKU was
      # missing" rather than reciting every row.
      #
      # Counted over a sample rather than the whole failure set, because an
      # import that failed wholesale has as many rows as the file did. The
      # counts therefore say `rows_in_sample`, not `rows`: reporting a sample
      # as a total would have the assistant tell the merchant twelve rows
      # failed when twelve hundred did.
      def failure_reasons(import)
        failed = import.rows.failed.limit(SCANNED_ROW_LIMIT).to_a
        return if failed.empty?

        reasons = failed.filter_map { |row| row.validation_errors.presence }
                        .tally
                        .sort_by { |_reason, count| -count }
                        .first(FAILED_ROW_SAMPLE)
                        .map { |reason, count| { reason: reason, rows_in_sample: count } }

        { scanned: failed.size, total_failed: import.rows.failed.count, reasons: reasons }
      end
    end
  end
end
