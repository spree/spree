module Spree
  class WorkflowStepExecution < Spree.base_class
    STATUSES = %w[pending running completed failed compensated compensation_failed skipped].freeze

    belongs_to :workflow_execution,
               class_name: 'Spree::WorkflowExecution',
               inverse_of: :step_executions

    validates :step_id, presence: true
    validates :status, presence: true, inclusion: { in: STATUSES }
    validates :position, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    scope :pending, -> { where(status: 'pending') }
    scope :running, -> { where(status: 'running') }
    scope :completed, -> { where(status: 'completed') }
    scope :failed, -> { where(status: 'failed') }
    scope :compensated, -> { where(status: 'compensated') }
    scope :needs_compensation, -> { where(status: 'completed').order(position: :desc) }
    scope :async, -> { where(async: true) }
    scope :ordered, -> { order(:position) }

    before_validation :set_defaults, on: :create

    def pending?
      status == 'pending'
    end

    def running?
      status == 'running'
    end

    def completed?
      status == 'completed'
    end

    def failed?
      status == 'failed'
    end

    def compensated?
      status == 'compensated'
    end

    def compensation_failed?
      status == 'compensation_failed'
    end

    def skipped?
      status == 'skipped'
    end

    def async?
      async
    end

    def duration
      return nil unless started_at && completed_at

      completed_at - started_at
    end

    def mark_running!
      update!(status: 'running', started_at: Time.current, attempts: attempts + 1)
    end

    def mark_completed!(output:, compensation_data: nil)
      update!(
        status: 'completed',
        output: output,
        compensation_data: compensation_data || output,
        completed_at: Time.current,
        error_message: nil,
        error_class: nil
      )
    end

    def mark_failed!(error)
      update!(
        status: 'failed',
        error_message: error.message,
        error_class: error.class.name,
        completed_at: Time.current
      )
    end

    def mark_compensated!
      update!(status: 'compensated', completed_at: Time.current)
    end

    def mark_compensation_failed!(error)
      update!(
        status: 'compensation_failed',
        error_message: "Compensation failed: #{error.message}",
        completed_at: Time.current
      )
    end

    private

    def set_defaults
      self.status ||= 'pending'
      self.attempts ||= 0
    end
  end
end
