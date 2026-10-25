module Spree
  module MaintenanceTasks
    # Executes one Spree::MaintenanceTaskRun on Active Job Continuations
    # (docs/plans/6.0-maintenance-tasks.md).
    #
    # Three things can stop a run mid-collection, and all three resolve to the
    # same checkpoint: the worker is shutting down (Continuations re-queue the
    # job), the execution has used its time slice (the runner re-queues
    # itself so no single task holds a worker), or an operator asked to
    # cancel (the Cancel service writes the request, the runner observes it
    # here). The run row's cursor is written before each checkpoint, so
    # whichever path fires, the next execution restarts from the same record.
    class RunJob < ::Spree::BaseJob
      include ActiveJob::Continuable

      queue_as Spree.queues.maintenance_tasks

      # A run that fails is recorded as failed; it must not be replayed by the
      # backend behind the operator's back. Running it again is an explicit
      # action.
      #
      # `inline` is a run executing in the caller's own process — the
      # upgrade walk and the command line. It holds no worker, so it is not
      # sliced: handing the remainder to a worker would let the caller report
      # a step done that has not finished, on a deploy where no worker runs.
      def perform(run_id, inline: false)
        # Outside the steps on purpose — runs on every execution, resumes
        # included.
        @run = Spree::MaintenanceTaskRun.find_by(id: run_id)
        return if @run.nil?
        # `cancelling` counts as active: a job re-queued after its worker
        # stopped is the only execution that will ever answer it.
        return unless @run.active?

        @task_class = @run.task_class
        return unfindable_task if @task_class.nil?

        @inline = inline
        @execution_started_at = Time.current
        @time_running_before = @run.time_running.to_f
        prepare
        return if @halted

        check_operator_request
        return if @halted
        return refuse_duplicate if duplicate_run?

        step :start
        # Seeded from the row rather than from the continuation: the row
        # survives a dropped job, which a re-queued execution then picks up
        # with no continuation at all.
        step :process_collection, start: @run.cursor
        step :finish
      end

      private

      attr_reader :run, :task

      def start
        return if run.running?

        started = write_status('running', from: %w[enqueued interrupted],
                                          started_at: run.started_at || Time.current,
                                          job_id: job_id,
                                          tick_total: run.tick_total || safe_count)
        # An operator cancelled the run after the check above.
        return check_operator_request unless started

        publish('started')
      rescue StandardError => e
        record_error(e)
      end

      # Outside the steps, so an error here would never reach the rescues
      # below: a run whose arguments no longer fit its task (a deploy removed
      # a parameter) would stay queued forever, or be resumed by Continuations
      # without end. Recorded as a failure instead.
      def prepare
        @task = @task_class.new(@run.arguments.presence || {})
        @task.run = @run
        resume_after_time_slice
      rescue StandardError => e
        record_error(e)
      end

      # One run per task is checked when a run is created, but two requests
      # can both pass that check before either is saved. The older run wins,
      # so the outcome does not depend on which worker picks a job up first.
      def duplicate_run?
        return false unless run.enqueued?

        run.class.active.where(task_name: run.task_name).where(run.class.arel_table[:id].lt(run.id)).exists?
      end

      def refuse_duplicate
        close_run('cancelled', 'Spree::MaintenanceTasks::AlreadyRunning',
                  "#{run.task_api_type} was already running, so this run did not start")
        publish('cancelled')
      end

      # Continuations skip `start` once it has completed, so an execution
      # picking up after its time slice would otherwise keep reporting
      # `interrupted` while it works — and the Cancel service would treat it as
      # idle. Conditional, so a cancel written while the job sat
      # in the queue is not overwritten.
      def resume_after_time_slice
        return unless run.interrupted?

        run.class.where(id: run.id, status: 'interrupted').update_all(status: 'running', updated_at: Time.current)
        run.reload
      end

      # The collection walk. Batches are fetched by cursor rather than by
      # offset so a resumed execution reads nothing it has already processed.
      def process_collection(step)
        return if @halted

        if task.no_collection?
          process_single
          return
        end

        loop do
          break if @halted

          items = next_batch(step.cursor)
          break if items.empty?

          process_batch(items)
          break if @halted

          # One cursor value, the last id seen, written to the row and to the
          # continuation. Persisted before the checkpoint — an interruption
          # between these two lines must not lose the batch already applied.
          cursor = items.last.id.to_s
          persist_progress(cursor: cursor, count: items.size)
          step.set!(cursor)

          check_operator_request
          check_time_slice(step)
        end
      rescue StandardError => e
        # Not discard_on: Continuations resume errors raised after progress,
        # so a discard handler would never see them and the run would loop.
        record_error(e)
      end

      # The callback runs before the row is written so a task can summarise in
      # `after_complete` — tallying there and persisting first would silently
      # drop whatever it recorded.
      def finish
        return if @halted

        task.after_complete
        return check_operator_request unless write_status('succeeded', from: 'running',
                                                                       ended_at: Time.current,
                                                                       tallies: merged_tallies)

        publish('succeeded')
      rescue StandardError => e
        record_error(e)
      end

      # A no_collection task is one unit of work: no cursor, no partial
      # progress, and an error fails the whole run.
      def process_single
        task.process
        persist_progress(cursor: nil, count: 1)
      rescue StandardError => e
        record_error(e)
      end

      def process_batch(items)
        items.each { |item| task.process(item) }
      end

      # Cursor-paged rather than find_each: the cursor has to survive between
      # executions, which an in-memory batch enumerator cannot do.
      def next_batch(cursor)
        scope = task.collection
        scope = scope.where(scope.arel_table[scope.primary_key].gt(cursor)) if cursor.present?
        scope.limit(task.class.batch_size).to_a
      end

      # update_columns rather than update!: progress is written on every batch
      # and carries no validation of its own.
      def persist_progress(cursor:, count:)
        run.update_columns(
          cursor: cursor,
          tick_count: run.tick_count + count,
          tallies: merged_tallies,
          time_running: accumulated_time,
          updated_at: Time.current
        )
      end

      # Cancel is a request written to the row by the Cancel service; the
      # runner is the only writer of the resulting state, so a killed worker
      # can never leave `cancelled` on a run that is still moving.
      #
      # Read once per batch rather than on a timer: a primary-key read costs
      # nothing beside the batch of writes it follows, and a time-based
      # throttle would make a fast task ignore a cancel altogether — the
      # batches would all land inside one interval.
      def check_operator_request
        requested = run.class.where(id: run.id).pick(:status)
        return unless requested.in?(%w[cancelling cancelled])

        write_status('cancelled', from: requested, ended_at: Time.current, time_running: accumulated_time)
        publish('cancelled')
        @halted = true
      end

      # The control services write to the same row this job holds in memory,
      # so the write only lands while the row is still in the status the
      # runner expects. Otherwise an operator's cancel, written
      # between the runner's read and its write, would be overwritten.
      #
      # @return [Boolean] whether the row was in an expected status
      def write_status(status, from:, **attributes)
        written = run.class.where(id: run.id, status: from).
                  update_all(status: status, updated_at: Time.current, **attributes)
        run.reload
        written.positive?
      end

      def check_time_slice(step)
        return if @inline
        return if Time.current - @execution_started_at < Spree::MaintenanceTask::MAX_RUN_TIME

        return check_operator_request unless write_status('interrupted', from: 'running',
                                                                         time_running: accumulated_time)

        publish('interrupted')
        # Raises Continuation::Interrupt, which inherits Exception and is
        # never caught by the rescues above.
        interrupt!(reason: :run_time_limit)
      end

      # Recording a failure must never fail. This is the last thing standing
      # between a crashed task and a run stuck in `running` forever, so it
      # writes columns directly rather than going through validations that
      # could reject the very state that describes the problem.
      def record_error(error)
        run.reload
        run.update_columns(
          status: 'errored',
          ended_at: Time.current,
          time_running: accumulated_time,
          tallies: merged_tallies,
          error_class: error.class.name,
          error_message: error.message.to_s.truncate(1000),
          error_backtrace: cleaned_backtrace(error),
          updated_at: Time.current
        )
        publish('errored')
        Rails.error.report(error, handled: true)
        @halted = true
      end

      def cleaned_backtrace(error)
        return nil if error.backtrace.blank?

        Rails.backtrace_cleaner.clean(error.backtrace).first(50).join("\n")
      end

      # The task was removed from the registry between enqueue and execution —
      # a deploy that dropped it. Recorded rather than raised: retrying cannot
      # bring the class back.
      def unfindable_task
        close_run('errored', 'Spree::MaintenanceTasks::TaskNotRegistered',
                  "#{run.task_name} is not a registered maintenance task")
      end

      # Ends a run that never started work, so there is nothing to tally.
      def close_run(status, error_class, error_message)
        run.update_columns(status: status, ended_at: Time.current, error_class: error_class,
                           error_message: error_message, updated_at: Time.current)
      end

      # Summed, not replaced: a task instance counts only what the current
      # execution did, so an interrupted run that merged would report its last
      # slice as the whole total. Baselined at the first checkpoint of each
      # execution so repeated writes within one execution stay accurate.
      def merged_tallies
        @tally_baseline ||= (run.tallies || {}).dup
        return @tally_baseline.dup if task.nil?

        task.tallies.each_with_object(@tally_baseline.dup) do |(key, value), result|
          result[key] = result.fetch(key, 0) + value
        end
      end

      # From the total this execution started with, never the row's current
      # value: progress rewrites the row every batch, so adding elapsed time
      # to it would count the same seconds again on each write.
      def accumulated_time
        return run.time_running if @execution_started_at.nil?

        @time_running_before + (Time.current - @execution_started_at)
      end

      def safe_count
        task.count
      rescue StandardError
        nil
      end

      def publish(event)
        run.publish_event("maintenance_task_run.#{event}")
      end
    end
  end
end
