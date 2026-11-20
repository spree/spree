require 'spec_helper'

RSpec.describe Spree::MaintenanceTasks::Upgrade::BackfillSettlementStatuses do
  let(:store) { @default_store }
  let(:order) { create(:completed_order_with_totals, store: store) }
  let(:payment) { create(:payment, order: order, status: 'completed', amount: 100) }

  let!(:unset_capture) { create(:payment_capture_event, payment: payment).tap { |event| event.update_column(:status, nil) } }
  let!(:requested_capture) { create(:payment_capture_event, :requested, payment: payment) }
  let!(:unset_refund) { create(:refund, payment: payment, amount: 10).tap { |refund| refund.update_column(:status, nil) } }
  let!(:failed_refund) { create(:refund, :failed, payment: payment, amount: 10) }

  def run_task(dry_run: false)
    result = Spree::MaintenanceTasks::Start.call(task_name: described_class.name, dry_run: dry_run, initiated_via: 'cli')
    Spree::MaintenanceTasks::RunJob.perform_now(result.value.id)
    result.value.reload
  end

  it 'marks empty capture events and refunds completed' do
    run = run_task

    expect(unset_capture.reload.read_attribute(:status)).to eq('completed')
    expect(unset_refund.reload.read_attribute(:status)).to eq('completed')
    expect(run.tallies).to include('capture_events_completed' => 1, 'refunds_completed' => 1)
  end

  it 'leaves requested and failed rows alone' do
    run_task

    expect(requested_capture.reload.status).to eq('requested')
    expect(failed_refund.reload.status).to eq('failed')
  end

  it 'changes nothing on a second run' do
    run_task

    expect { run_task }.not_to(change { [unset_capture.reload.updated_at, unset_refund.reload.updated_at] })
  end

  it 'reports without writing in a dry run' do
    run = run_task(dry_run: true)

    expect(unset_capture.reload.read_attribute(:status)).to be_nil
    expect(run.tallies).to include('capture_events_would_complete' => 1, 'refunds_would_complete' => 1)
  end
end
