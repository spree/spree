require 'spec_helper'

RSpec.describe Spree::MaintenanceTasks::Upgrade::CaptureMethods do
  let(:store) { @default_store }

  def run_task
    result = Spree::MaintenanceTasks::Start.call(task_name: described_class.name, initiated_via: 'cli')
    Spree::MaintenanceTasks::RunJob.perform_now(result.value.id)
    result.value.reload
  end

  it 'converts capture-on-authorization into charging at checkout' do
    payment_method = create(:payment_method, store: store)
    payment_method.update_columns(auto_capture: true, capture_method: nil)

    run = run_task

    expect(payment_method.reload.capture_method).to eq('checkout')
    expect(run.tallies['converted']).to eq(1)
  end

  # The boolean only recorded "not at checkout"; it could not say whether
  # dispatch or staff was meant to charge, so the store keeps deciding.
  it 'leaves a method that did not capture on authorization inheriting' do
    payment_method = create(:payment_method, store: store)
    payment_method.update_columns(auto_capture: false, capture_method: nil)

    run = run_task

    expect(payment_method.reload.capture_method).to be_nil
    expect(run.tallies['left_inheriting_store_setting']).to eq(1)
  end

  it 'never overwrites a method that already has a capture method' do
    payment_method = create(:payment_method, store: store)
    payment_method.update_columns(auto_capture: true, capture_method: 'manual')

    run_task

    expect(payment_method.reload.capture_method).to eq('manual')
  end
end
