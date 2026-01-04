FactoryBot.define do
  factory :workflow_execution, class: 'Spree::WorkflowExecution' do
    workflow_id { 'test_workflow' }
    transaction_id { SecureRandom.uuid }
    status { 'pending' }
    input { {} }
    context { {} }
    store { nil }

    trait :running do
      status { 'running' }
      started_at { Time.current }
    end

    trait :waiting do
      status { 'waiting' }
      started_at { Time.current }
    end

    trait :completed do
      status { 'completed' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
      output { { result: 'success' } }
    end

    trait :failed do
      status { 'failed' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
      error_message { 'Something went wrong' }
      error_class { 'StandardError' }
    end

    trait :compensating do
      status { 'compensating' }
      started_at { 1.minute.ago }
    end

    trait :compensated do
      status { 'compensated' }
      started_at { 1.minute.ago }
      completed_at { Time.current }
    end

    trait :with_store do
      store { create(:store) }
    end

    trait :with_steps do
      after(:create) do |execution|
        create(:workflow_step_execution,
               workflow_execution: execution,
               step_id: 'step_1',
               position: 0,
               status: 'completed')
        create(:workflow_step_execution,
               workflow_execution: execution,
               step_id: 'step_2',
               position: 1,
               status: 'pending')
      end
    end
  end
end
