require 'spec_helper'
require 'rake'

RSpec.describe 'spree:maintenance_tasks rake tasks' do
  let(:store) { @default_store }

  before(:all) do
    Rake.application.rake_require('tasks/maintenance_tasks', [Spree::Core::Engine.root.join('lib').to_s])
    Rake::Task.define_task(:environment)
  end

  def run_task(name, *args)
    task = Rake::Task[name]
    task.reenable
    silence_stream($stdout) { task.invoke(*args) }
  end

  describe 'perform' do
    it 'runs the task and records a CLI-initiated run' do
      order = create(:order, store: store)
      order.update_columns(market_id: nil)

      run_task('spree:maintenance_tasks:perform', 'Spree::MaintenanceTasks::Upgrade::BackfillOrderMarkets')

      run = Spree::MaintenanceTaskRun.last
      expect(run.initiated_via).to eq('cli')
      expect(run).to be_succeeded
      expect(order.reload.market_id).to eq(store.default_market.id)
    end

    it 'honors DRY_RUN' do
      order = create(:order, store: store)
      order.update_columns(market_id: nil)
      ENV['DRY_RUN'] = '1'

      run_task('spree:maintenance_tasks:perform', 'Spree::MaintenanceTasks::Upgrade::BackfillOrderMarkets')

      expect(Spree::MaintenanceTaskRun.last).to be_dry_run
      expect(order.reload.market_id).to be_nil
    ensure
      ENV.delete('DRY_RUN')
    end

    it 'aborts on an unknown task rather than failing silently' do
      expect {
        run_task('spree:maintenance_tasks:perform', 'Nope::Task')
      }.to raise_error(SystemExit)
    end
  end

  describe 'list' do
    it 'names the registered tasks' do
      expect { run_task('spree:maintenance_tasks:list') }.not_to raise_error
    end
  end
end
