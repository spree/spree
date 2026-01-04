module Spree
  class WorkflowExecution < Spree.base_class
    STATUSES = %w[pending running waiting completed failed compensating compensated].freeze

    belongs_to :store, class_name: 'Spree::Store', optional: true
    has_many :step_executions,
             class_name: 'Spree::WorkflowStepExecution',
             dependent: :destroy,
             inverse_of: :workflow_execution

    validates :workflow_id, presence: true
    validates :transaction_id, presence: true, uniqueness: { scope: spree_base_uniqueness_scope }
    validates :status, presence: true, inclusion: { in: STATUSES }

    scope :pending, -> { where(status: 'pending') }
    scope :running, -> { where(status: 'running') }
    scope :waiting, -> { where(status: 'waiting') }
    scope :completed, -> { where(status: 'completed') }
    scope :failed, -> { where(status: 'failed') }
    scope :for_workflow, ->(workflow_id) { where(workflow_id: workflow_id) }

    before_validation :set_defaults, on: :create

    # Status predicates
    STATUSES.each do |status_name|
      define_method(:"#{status_name}?") { status == status_name }
    end

    def can_resume?
      waiting? || (failed? && step_executions.pending.exists?)
    end

    def completed_steps
      step_executions.completed.order(:position)
    end

    def current_step
      step_executions.find_by(step_id: current_step_id)
    end

    def progress_percentage
      return 0 if step_executions.empty?

      (step_executions.completed.count.to_f / step_executions.count * 100).round
    end

    # Result interface (previously in ExecutionResult)

    def success?
      completed?
    end

    def failure?
      failed?
    end

    def error
      error_message
    end

    def duration
      return nil unless started_at && completed_at

      completed_at - started_at
    end

    def steps_summary
      step_executions.ordered.map do |step|
        {
          id: step.step_id,
          status: step.status,
          attempts: step.attempts,
          duration: step.duration,
          error: step.error_message
        }
      end
    end

    def to_result_hash
      {
        transaction_id: transaction_id,
        workflow_id: workflow_id,
        status: status,
        output: output,
        error: error_message,
        progress: progress_percentage,
        started_at: started_at,
        completed_at: completed_at,
        duration: duration,
        steps: steps_summary
      }
    end

    private

    def set_defaults
      self.transaction_id ||= SecureRandom.uuid
      self.status ||= 'pending'
      self.context ||= {}
    end
  end
end
