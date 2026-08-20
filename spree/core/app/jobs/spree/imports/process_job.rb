module Spree
  module Imports
    # The sequential spine of the import pipeline on ActiveJob
    # Continuations: CSV streaming into ImportRow records (cursor = row
    # number, so a deploy mid-stream resumes instead of restarting the
    # parse), then group dispatch. The parallel per-group processing stays
    # on ProcessGroupJob — its crash-safety comes from row statuses and
    # the completion counters. A malformed file is a permanent failure,
    # handled inside the create_rows step, never a retry loop.
    #
    # `skip_row_creation: true` is the retry entry (rows already exist,
    # only failed/pending ones get re-dispatched). Inline callers (seeds,
    # sample data) run the same steps synchronously via `perform_now`.
    class ProcessJob < Spree::Imports::BaseJob
      include ActiveJob::Continuable

      ROW_BATCH_SIZE = 1000
      GROUP_BATCH_SIZE = 100
      UNGROUPED_KEY = '__ungrouped__'.freeze

      def perform(import_id, skip_row_creation: false)
        # Outside the steps on purpose — runs on every execution, including
        # resumes after an interruption.
        @import = Spree::Import.find(import_id)

        unless skip_row_creation
          step :begin_processing do
            if @import.status != 'processing'
              result = Spree.import_start_processing_workflow.call(import: @import)
              # Row creation must not start from an import the workflow
              # refused to move; raising fails the job rather than building
              # rows against a status that never advanced.
              raise ActiveRecord::RecordInvalid, @import if result.failure?
            end
          end
          step :create_rows, start: 1
          # A permanent CSV failure marked the import failed inside the step
          # (rescuing there, not via discard_on — Continuable resumes errors
          # raised after progress, so discard handlers would never run).
          return if @csv_failed

          step :reset_row_counters do
            Spree::Import.reset_counters(@import.id, :rows)
          end
        end

        step :dispatch_row_groups
      end

      private

      # Streams the CSV so the whole file never sits in memory; the cursor
      # is the next row number to insert, checkpointed once per batch. On
      # resume the stream is re-read but rows below the cursor are skipped —
      # progress is monotonic even under a rolling-deploy storm.
      def create_rows(step)
        rows_to_insert = []
        row_number = 1
        created_at = updated_at = Time.current

        upsert_options = {}
        if %w[PostgreSQL SQLite].include?(ActiveRecord::Base.connection.adapter_name)
          upsert_options[:unique_by] = :index_spree_import_rows_on_import_id_and_row_number
        end

        ::CSV.foreach(StringIO.new(@import.attachment_file_content),
                      headers: true,
                      col_sep: @import.preferred_delimiter,
                      encoding: 'UTF-8') do |csv_row|
          if row_number < step.cursor
            row_number += 1
            next
          end

          rows_to_insert << {
            import_id: @import.id,
            row_number: row_number,
            data: csv_row.to_h.to_json,
            status: 'pending',
            created_at: created_at,
            updated_at: updated_at
          }
          row_number += 1

          if rows_to_insert.size >= ROW_BATCH_SIZE
            Spree::ImportRow.upsert_all(rows_to_insert, **upsert_options)
            rows_to_insert.clear
            step.set!(row_number)
          end
        end

        Spree::ImportRow.upsert_all(rows_to_insert, **upsert_options) if rows_to_insert.any?
      rescue ::CSV::MalformedCSVError, EncodingError => e
        @import.update_columns(processing_errors: e.message, status: :failed, updated_at: Time.current)
        Rails.error.report(e)
        @csv_failed = true
      end

      def dispatch_row_groups
        group_field = @import.group_column
        group_mapping = group_field && @import.mappings.mapped.find_by(schema_field: group_field)
        file_column = group_mapping&.file_column

        if file_column
          dispatch_grouped(file_column)
        else
          dispatch_batched
        end
      end

      # Inline callers need the group finished before `perform` returns; the
      # group job's completion bookkeeping works either way.
      def dispatch_group(row_ids)
        return ProcessGroupJob.perform_now(@import.id, row_ids) if @import.preferred_inline

        ProcessGroupJob.perform_later(@import.id, row_ids)
      end

      def dispatch_grouped(file_column)
        groups = Hash.new { |hash, key| hash[key] = [] }

        @import.rows.pending_and_failed.order(:row_number).pluck(:id, :data).each do |id, data|
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
        ungrouped&.each_slice(GROUP_BATCH_SIZE) { |row_ids| batches << row_ids }

        # Set count before enqueuing so workers can't complete prematurely
        @import.update_columns(
          processing_groups_count: batches.size,
          completed_groups_count: 0,
          updated_at: Time.current
        )

        batches.each { |row_ids| dispatch_group(row_ids) }
      end

      def dispatch_batched
        # Count first, then enqueue — prevents premature completion
        row_id_batches = @import.rows.pending_and_failed.order(:row_number)
                                .pluck(:id)
                                .each_slice(GROUP_BATCH_SIZE)
                                .to_a

        @import.update_columns(
          processing_groups_count: row_id_batches.size,
          completed_groups_count: 0,
          updated_at: Time.current
        )

        row_id_batches.each { |row_ids| dispatch_group(row_ids) }
      end
    end
  end
end
