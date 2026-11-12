FactoryBot.define do
  factory :maintenance_task_run, class: 'Spree::MaintenanceTaskRun' do
    task_name { 'Spree::MaintenanceTasks::BackfillOrderMarkets' }
    status { 'enqueued' }
    initiated_via { 'api' }
  end
end
