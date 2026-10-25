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

    publishes_lifecycle_events
    publishes_events :started, :succeeded, :cancelled, :interrupted, :errored

    # Terminal statuses end a run for good; a failed run is started again
    # rather than resumed. `cancelling` is the operator's request, written by
    # the Cancel service and observed by the runner at its next checkpoint —
    # the runner alone moves a running run into `cancelled`, so a stopped
    # worker can never leave a lie in the column.
    has_status :enqueued, :running, :interrupted, :cancelling, :cancelled,
               :succeeded, :errored,
               default: :enqueued

    ACTIVE_STATUSES = %w[enqueued running interrupted cancelling].freeze
    INITIATED_VIA = %w[dashboard api cli].freeze

    belongs_to :store, class_name: 'Spree::Store', optional: true
    belongs_to :admin_user, class_name: Spree.admin_user_class.to_s, optional: true
    belongs_to :api_key, class_name: 'Spree::ApiKey', optional: true

    validates :task_name, presence: true
    validates :initiated_via, presence: true, inclusion: { in: INITIATED_VIA }

    scope :active, -> { where(status: ACTIVE_STATUSES) }

    self.whitelisted_ransackable_attributes = %w[task_name status created_at]

    # Filtered by the task's short name, which is what responses carry; the
    # column holds its class name. A partial value (`task_name_cont=capture`)
    # is camelized so a search still matches part of the stored name.
    ransacker :task_name, formatter: ->(value) {
      Spree::MaintenanceTask.find_by_api_type(value)&.name || value.to_s.camelize
    } do |parent|
      parent.table[:task_name]
    end

    # @return [Class, nil] the registered task class, or nil when the task has
    #   been removed from the registry since the run was created
    def task_class
      Spree::MaintenanceTask.find_registered(task_name)
    end

    # The task's short name, as the API and the dashboard identify it.
    #
    # @return [String]
    def task_api_type
      Spree::MaintenanceTask.api_type_for(task_name)
    end

    def active?
      ACTIVE_STATUSES.include?(status)
    end

    # Seconds of work. Time since the last checkpoint counts only while a
    # worker holds the run — a queued run is not working.
    def duration
      return time_running unless status.in?(%w[running cancelling]) && started_at.present?

      time_running + (Time.current - (updated_at || started_at))
    end
  end
end
