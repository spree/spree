require 'spec_helper'

RSpec.describe Spree::MaintenanceTasks::Upgrade::BackfillOrderMarkets do
  let(:store) { @default_store }

  def run_task(dry_run: false)
    result = Spree::MaintenanceTasks::Start.call(task_name: described_class.name,
                                                 dry_run: dry_run, initiated_via: 'cli')
    Spree::MaintenanceTasks::RunJob.perform_now(result.value.id)
    result.value.reload
  end

  it 'assigns each order its own store default market' do
    order = create(:order, store: store)
    order.update_columns(market_id: nil)

    run = run_task

    expect(order.reload.market_id).to eq(store.default_market.id)
    expect(run).to be_succeeded
    expect(run.tallies['updated']).to eq(1)
  end

  it 'leaves orders that already have a market alone' do
    order = create(:order, store: store)
    original_market_id = order.market_id

    run_task

    expect(order.reload.market_id).to eq(original_market_id)
  end

  # Re-running the manifest step is expected: the second pass has nothing left
  # to find, because assigned orders drop out of the collection.
  it 'is idempotent' do
    order = create(:order, store: store)
    order.update_columns(market_id: nil)
    run_task

    Spree::MaintenanceTaskRun.last.update!(status: 'succeeded')
    second = run_task

    expect(second.tick_count).to be_zero
    expect(order.reload.market_id).to eq(store.default_market.id)
  end

  describe 'dry run' do
    it 'reports what it would change without writing' do
      order = create(:order, store: store)
      order.update_columns(market_id: nil)

      run = run_task(dry_run: true)

      expect(order.reload.market_id).to be_nil
      expect(run.tallies['would_update']).to eq(1)
    end
  end

  describe 'a store with no default market' do
    # Failing the run would strand every other store's orders behind a store
    # that has nothing to assign.
    it 'counts the orders it skipped and finishes' do
      order = create(:order, store: store)
      order.update_columns(market_id: nil)
      allow_any_instance_of(Spree::Store).to receive(:default_market).and_return(nil)

      run = run_task

      expect(run).to be_succeeded
      expect(run.tallies['skipped_no_default_market']).to eq(1)
      expect(order.reload.market_id).to be_nil
    end
  end
end
