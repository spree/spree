module Spree
  module Imports
    class ProcessRowsJob < Spree::Imports::BaseJob
      BATCH_SIZE = 100
      UNGROUPED_KEY = '__ungrouped__'.freeze

      def perform(import_id)
        import = Spree::Import.find(import_id)
        dispatch_groups(import)
      end

      private

      def dispatch_groups(import)
        group_field = import.group_column
        group_mapping = group_field && import.mappings.mapped.find_by(schema_field: group_field)
        file_column = group_mapping&.file_column

        if file_column
          dispatch_grouped(import, file_column)
        else
          dispatch_batched(import)
        end
      end

      def dispatch_grouped(import, file_column)
        groups = Hash.new { |h, k| h[k] = [] }

        import.rows.pending_and_failed.order(:row_number).pluck(:id, :data).each do |id, data|
          parsed = JSON.parse(data)
          key = parsed[file_column].to_s.strip.downcase.presence || UNGROUPED_KEY
          groups[key] << id
        rescue JSON::ParserError
          groups[UNGROUPED_KEY] << id
        end

        # Rows without a group value don't depend on each other, so they don't have
        # to share a single job — split them into bounded batches. Real groups stay
        # intact: their rows must run sequentially (product row before variant rows).
        ungrouped = groups.delete(UNGROUPED_KEY)
        batches = groups.values
        ungrouped&.each_slice(BATCH_SIZE) { |row_ids| batches << row_ids }

        # Set count before enqueuing so workers can't complete prematurely
        import.update_columns(
          processing_groups_count: batches.size,
          completed_groups_count: 0,
          updated_at: Time.current
        )

        batches.each { |row_ids| ProcessGroupJob.perform_later(import.id, row_ids) }
      end

      def dispatch_batched(import)
        # Count first, then enqueue — prevents premature completion
        row_id_batches = import.rows.pending_and_failed.order(:row_number)
                              .pluck(:id)
                              .each_slice(BATCH_SIZE)
                              .to_a

        import.update_columns(
          processing_groups_count: row_id_batches.size,
          completed_groups_count: 0,
          updated_at: Time.current
        )

        row_id_batches.each { |row_ids| ProcessGroupJob.perform_later(import.id, row_ids) }
      end
    end
  end
end
