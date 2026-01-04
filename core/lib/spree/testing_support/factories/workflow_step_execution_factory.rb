FactoryBot.define do
  factory :workflow_step_execution, class: 'Spree::WorkflowStepExecution' do
    workflow_execution
    sequence(:step_id) { |n| "step_#{n}" }
    sequence(:position) { |n| n }
    status { 'pending' }
    attempts { 0 }
    async { false }

    trait :running do
      status { 'running' }
      started_at { Time.current }
      attempts { 1 }
    end

    trait :completed do
      status { 'completed' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
      attempts { 1 }
      output { { result: 'done' } }
      compensation_data { { rollback_id: 123 } }
    end

    trait :failed do
      status { 'failed' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
      attempts { 1 }
      error_message { 'Step failed' }
      error_class { 'StandardError' }
    end

    trait :compensated do
      status { 'compensated' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
      output { { result: 'done' } }
      compensation_data { { rollback_id: 123 } }
    end

    trait :compensation_failed do
      status { 'compensation_failed' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
      error_message { 'Compensation failed: unable to rollback' }
    end

    trait :skipped do
      status { 'skipped' }
    end

    trait :async do
      async { true }
    end

    trait :with_output do
      output { { value: 'test', id: 123 } }
    end

    trait :with_compensation_data do
      compensation_data { { resource_id: 456, action: 'delete' } }
    end
  end
end
