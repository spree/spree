module Spree
  # One execution of a Spree::MaintenanceTask — the durable record of what was
  # run, by whom, with which arguments, and how far it got
  # (docs/plans/6.0-maintenance-tasks.md).
  #
  # The row is both the checkpoint and the audit trail. Its `cursor` is the
  # authoritative resume point: Active Job serializes its own continuation
  # into the job data, but that copy is lost whenever the job is dropped by
  # the backend, so the runner writes both in the same checkpoint and always
  # seeds from this column.
  #
  # Runs are installation-wide. `store` records the store the operator was
  # acting in — the runner loads it into Spree::Current.store — and is not
  # ownership: a backfill routinely walks every store's data.
  class MaintenanceTaskRun < Spree.base_class
    has_prefix_id :mtr

    include Spree::HasStatus
    include Spree::Metadata

    publishes_lifecycle_events

    # Terminal statuses end a run for good; a paused or errored run can still
    # be resumed from its cursor. `pausing` and `cancelling` are the operator's
    # request, written by the control services and observed by the runner at
    # its next checkpoint — the runner alone moves a run into `paused` or
    # `cancelled`, so a stopped worker can never leave a lie in the column.
    has_status :enqueued, :running, :pausing, :paused, :interrupted,
               :cancelling, :cancelled, :succeeded, :errored,
               default: :enqueued

    ACTIVE_STATUSES = %w[enqueued running pausing paused interrupted cancelling].freeze
    TERMINAL_STATUSES = %w[succeeded errored cancelled].freeze
    INITIATED_VIA = %w[dashboard api cli inline].freeze

    # The file a CSV task reads its rows from. Private storage: an uploaded
    # spreadsheet is merchant data, and a run keeps it as the record of what
    # was applied.
    has_one_attached :csv_file, service: Spree.private_storage_service_name

    belongs_to :parent_run, class_name: 'Spree::MaintenanceTaskRun', optional: true,
                            inverse_of: :child_runs
    belongs_to :store, class_name: 'Spree::Store', optional: true
    belongs_to :admin_user, class_name: Spree.admin_user_class.to_s, optional: true
    belongs_to :api_key, class_name: 'Spree::ApiKey', optional: true

    has_many :child_runs, class_name: 'Spree::MaintenanceTaskRun', foreign_key: :parent_run_id,
                          dependent: :nullify, inverse_of: :parent_run

    validates :task_name, presence: true
    validates :initiated_via, presence: true, inclusion: { in: INITIATED_VIA }

    scope :active, -> { where(status: ACTIVE_STATUSES) }
    scope :terminal, -> { where(status: TERMINAL_STATUSES) }

    self.whitelisted_ransackable_attributes = %w[task_name status dry_run initiated_via created_at]
    self.whitelisted_ransackable_associations = %w[admin_user store]

    # @return [Class, nil] the registered task class, or nil when the task has
    #   been removed from the registry since the run was created
    def task_class
      Spree::MaintenanceTask.find_registered(task_name)
    end

    def active?
      ACTIVE_STATUSES.include?(status)
    end

    def terminal?
      TERMINAL_STATUSES.include?(status)
    end

    # A run resumes from its cursor after an operator pause or a failure. An
    # interrupted run needs no operator action — the backend already re-queued
    # it — so it is deliberately not resumable by hand.
    def resumable?
      paused? || errored?
    end

    def cancelable?
      active? && !cancelling?
    end

    # @return [Float, nil] 0.0..1.0, or nil when the task could not count its
    #   collection (the dashboard then shows ticks without a bar)
    def progress
      return nil if tick_total.nil? || tick_total.zero?

      [tick_count.to_f / tick_total, 1.0].min
    end

    def duration
      return time_running if ended_at.present? || started_at.blank?

      time_running + (Time.current - (updated_at || started_at))
    end

    # Arguments with masked values replaced, for anything that renders a run:
    # the API, the dashboard and the CLI all read through here so a secret
    # passed as a task parameter is never echoed back.
    def display_arguments
      values = arguments.presence || {}
      masked = task_class.respond_to?(:masked_attributes) ? task_class.masked_attributes : []

      values.each_with_object({}) do |(key, value), result|
        result[key] = masked.include?(key.to_s) ? Spree::MaintenanceTask::MASKED_VALUE : value
      end
    end
  end
end
