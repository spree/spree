module Spree
  module MaintenanceTasks
    # Executes one Spree::MaintenanceTaskRun on Active Job Continuations
    # (docs/plans/6.0-maintenance-tasks.md).
    #
    # Three things can stop a run mid-collection, and all three resolve to the
    # same checkpoint: the worker is shutting down (Continuations re-queue the
    # job), the execution has used its time slice (the runner re-queues
    # itself so no single task holds a worker), or an operator asked to pause
    # or cancel (the control services write the request, the runner observes
    # it here). The run row's cursor is written before each checkpoint, so
    # whichever path fires, the next execution restarts from the same record.
    class RunJob < ::Spree::BaseJob
      include ActiveJob::Continuable

      queue_as Spree.queues.maintenance_tasks

      # A run that fails is recorded as failed; it must not be replayed by the
      # backend behind the operator's back. Resuming is an explicit action.
      def perform(run_id)
        # Outside the steps on purpose — runs on every execution, resumes
        # included.
        @run = Spree::MaintenanceTaskRun.find_by(id: run_id)
        return if @run.nil?
        return unless @run.status.in?(%w[enqueued running interrupted])

        @task_class = @run.task_class
        return unfindable_task if @task_class.nil?

        Spree::Current.store = @run.store
        @task = @task_class.new(@run.arguments.presence || {})
        @task.run = @run
        @execution_started_at = Time.current

        step :start
        # Seeded from the row rather than from the continuation: the row
        # survives a dropped job, and an operator resume starts a brand new
        # job with no continuation at all.
        step :process_collection, start: @run.cursor
        step :finish
      end

      private

      attr_reader :run, :task

      def start
        return if run.running?

        run.update!(
          status: 'running',
          started_at: run.started_at || Time.current,
          job_id: job_id,
          tick_total: run.tick_total || safe_count
        )
        task.after_start
        publish('started')
      end

      # The collection walk. Batches are fetched by cursor rather than by
      # offset so a resumed execution reads nothing it has already processed.
      def process_collection(step)
        return if @halted

        if task.no_collection?
          process_single
          return
        end

        relation_backed = task.collection.is_a?(ActiveRecord::Relation)

        loop do
          break if @halted

          wait_for_throttles
          items = next_batch(step.cursor)
          break if items.empty?

          process_batch(items)
          break if @halted

          # One cursor value, written to the row and to the continuation:
          # a relation resumes after the last id seen, an array after the last
          # index consumed.
          cursor = if relation_backed
                     task.cursor_for(items.last)
                   else
                     (step.cursor.presence || 0).to_i + items.size
                   end

          # Persisted before the checkpoint — an interruption between these
          # two lines must not lose the batch that has already been applied.
          persist_progress(cursor: cursor.to_s, count: items.size)
          step.set!(cursor.to_s)

          check_operator_request
          check_time_slice(step)
        end
      rescue StandardError => e
        # Not discard_on: Continuations resume errors raised after progress,
        # so a discard handler would never see them and the run would loop.
        record_error(e)
      end

      def finish
        return if @halted

        write_status('succeeded', ended_at: Time.current, tallies: merged_tallies)
        task.after_complete
        publish('succeeded')
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
        items.each do |item|
          task.process(item)
        rescue StandardError => e
          raise e unless reportable?(e)

          Rails.error.report(e, handled: true, severity: severity_for(e))
          task.tally(:reported_errors)
        end
      end

      # Cursor-paged rather than find_each: the cursor has to survive between
      # executions, which an in-memory batch enumerator cannot do.
      def next_batch(cursor)
        items = task.collection
        return [] if items.blank?

        if items.is_a?(ActiveRecord::Relation)
          scope = items
          scope = scope.where(items.arel_table[items.primary_key].gt(cursor)) if cursor.present?
          scope.limit(task.class.batch_size).to_a
        else
          offset = cursor.to_i
          Array(items)[offset, task.class.batch_size] || []
        end
      end

      # update_columns rather than update!: progress is written on every batch
      # and carries no validation of its own, and skipping the lock_version
      # bump keeps the runner from invalidating its own record between
      # batches.
      def persist_progress(cursor:, count:)
        run.update_columns(
          cursor: cursor,
          tick_count: run.tick_count + count,
          tallies: merged_tallies,
          time_running: accumulated_time,
          updated_at: Time.current
        )
        publish('progress')
      end

      # Pause and cancel are requests written to the row by the control
      # services; the runner is the only writer of the resulting state, so a
      # killed worker can never leave `paused` on a run that is still moving.
      #
      # Read once per batch rather than on a timer: a primary-key read costs
      # nothing beside the batch of writes it follows, and a time-based
      # throttle would make a fast task ignore a pause altogether — the
      # batches would all land inside one interval.
      def check_operator_request
        case run.class.where(id: run.id).pick(:status)
        when 'pausing'
          write_status('paused', time_running: accumulated_time)
          task.after_pause
          publish('paused')
          @halted = true
        when 'cancelling'
          write_status('cancelled', ended_at: Time.current, time_running: accumulated_time)
          task.after_cancel
          publish('cancelled')
          @halted = true
        end
      end

      # The control services write to the same row this job holds in memory,
      # so the runner's copy is stale by construction whenever an operator has
      # acted. Reload before writing rather than carrying a lock_version the
      # operator was never going to respect — the runner is the only writer of
      # the resulting state, so there is nothing here to lose a race with.
      def write_status(status, **attributes)
        run.reload
        run.update!(status: status, **attributes)
      end

      def check_time_slice(step)
        return if Time.current - @execution_started_at < task.class.run_time_limit

        write_status('interrupted', time_running: accumulated_time)
        task.after_interrupt
        publish('interrupted')
        # Raises Continuation::Interrupt, which inherits Exception and is
        # never caught by the rescues above.
        interrupt!(reason: :run_time_limit)
      end

      # Throttles hold the execution rather than re-queueing it: Solid Queue's
      # polling granularity would round a short backoff up to something much
      # coarser than the condition needs.
      def wait_for_throttles
        task.class.throttle_conditions.each do |throttle|
          next unless instance_exec_condition(throttle[:condition])

          backoff = throttle[:backoff]
          backoff = backoff.call if backoff.respond_to?(:call)
          sleep([backoff.to_f, task.class.run_time_limit.to_f].min)
        end
      end

      def instance_exec_condition(condition)
        condition.arity.zero? ? task.instance_exec(&condition) : condition.call(task)
      end

      def reportable?(error)
        task.class.reported_errors.any? { |entry| error.is_a?(entry[:class]) }
      end

      def severity_for(error)
        entry = task.class.reported_errors.find { |candidate| error.is_a?(candidate[:class]) }
        entry ? entry[:severity] : :error
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
        task.after_error(error)
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
        @run.update_columns(
          status: 'errored',
          ended_at: Time.current,
          error_class: 'Spree::MaintenanceTasks::TaskNotRegistered',
          error_message: "#{@run.task_name} is not a registered maintenance task",
          updated_at: Time.current
        )
      end

      def merged_tallies
        (run.tallies || {}).merge(task.tallies)
      end

      def accumulated_time
        return run.time_running if @execution_started_at.nil?

        run.time_running + (Time.current - @execution_started_at)
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
