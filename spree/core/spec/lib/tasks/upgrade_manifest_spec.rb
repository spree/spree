require 'spec_helper'
require 'rake'
require 'spree/upgrade'

RSpec.describe 'the upgrade manifest' do
  let(:store) { @default_store }

  describe Spree::Upgrade do
    it 'reads every shipped manifest' do
      expect(described_class.manifests).to be_present
    end

    it 'carries the release boundary onto each step' do
      step = described_class.steps.first

      expect(step['from']).to be_present
      expect(step['to']).to be_present
    end

    it 'finds a step by id across manifests' do
      expect(described_class.find_step('migrate_capture_methods')).to be_present
    end

    it 'returns nothing for an unknown id' do
      expect(described_class.find_step('no_such_step')).to be_nil
    end
  end

  describe 'the 5.6 to 6.0 manifest' do
    let(:manifest) do
      Spree::Upgrade.manifests.find { |candidate| candidate['to'] == '6.0' }
    end

    # Every step of this manifest is a maintenance task, so a walk records what
    # it did. The rake names it used to carry never shipped in a release, which
    # is why they could be replaced rather than bridged.
    it 'names a task class for every step' do
      task_classes = manifest['steps'].map { |step| step['task_class'] }

      expect(task_classes).to all(be_present)
    end

    # An optional step's task class ships in the gem that owns it, so it is
    # absent here by design — that absence is exactly what makes the walk skip
    # the step instead of failing on an installation without the gem.
    it 'registers every task class it names, except the optional ones' do
      manifest['steps'].reject { |step| step['optional'] }.each do |step|
        expect(Spree::MaintenanceTask.find_registered(step['task_class'])).
          to be_present, "#{step['id']} names #{step['task_class']}, which is not registered"
      end
    end

    it 'leaves an optional step to the gem that owns it' do
      optional = manifest['steps'].select { |step| step['optional'] }

      expect(optional).not_to be_empty
      optional.each do |step|
        expect(Spree::MaintenanceTask.find_registered(step['task_class'])).to be_nil
      end
    end

    it 'keeps its steps in dependency order' do
      ids = manifest['steps'].map { |step| step['id'] }

      # Rich text is copied onto rows the customer migration creates, and
      # retyped by the taxon migration — it has to follow both.
      expect(ids.index('migrate_rich_text_to_columns')).
        to be > ids.index('migrate_users_to_customers')
      expect(ids.index('migrate_rich_text_to_columns')).
        to be > ids.index('migrate_taxons_to_categories_and_collections')
    end
  end

  describe 'released manifests' do
    # These names have shipped, so an operator may have scripted them; the
    # walker keeps running rake-backed steps for exactly that reason.
    it 'still name rake tasks' do
      released = Spree::Upgrade.manifests.reject { |manifest| manifest['to'] == '6.0' }

      expect(released).to be_present
      released.each do |manifest|
        expect(manifest['steps'].map { |step| step['task'] }).to all(be_present)
      end
    end
  end

  describe Spree::MaintenanceTasks::UpgradeStep do
    it 'refuses an id no manifest defines' do
      result = Spree::MaintenanceTasks::Start.call(
        task_name: described_class.name,
        arguments: { 'step_id' => 'no_such_step' },
        initiated_via: 'cli'
      )

      expect(result).to be_failure
      expect(result.error.to_s).to include('no upgrade step')
    end

    it 'runs the rake task the step names' do
      run = Spree::MaintenanceTasks::Start.call(
        task_name: described_class.name,
        arguments: { 'step_id' => 'product_tag_tenants' },
        initiated_via: 'cli',
        inline: true
      )

      expect(run).to be_success
      expect(run.value.reload).to be_succeeded
    end
  end

  describe Spree::MaintenanceTasks::Upgrade::CaptureMethods do
    let!(:payment_method) do
      create(:payment_method, store: store).tap do |method|
        method.update_columns(capture_method: nil, auto_capture: true)
      end
    end

    def run_task(dry_run: false)
      result = Spree::MaintenanceTasks::Start.call(
        task_name: described_class.name, dry_run: dry_run, initiated_via: 'cli', inline: true
      )
      result.value.reload
    end

    it 'converts methods that captured at authorization' do
      run = run_task

      expect(payment_method.reload.capture_method).to eq('checkout')
      expect(run.tallies['converted']).to eq(1)
    end

    it 'reports without writing in a preview' do
      run = run_task(dry_run: true)

      expect(payment_method.reload.capture_method).to be_nil
      expect(run.tallies['would_convert']).to eq(1)
    end

    # The old column could not say whether dispatch or staff was meant to take
    # the money, so those rows keep inheriting the store's setting.
    it 'leaves methods that did not capture at authorization inheriting' do
      other = create(:payment_method, store: store)
      other.update_columns(capture_method: nil, auto_capture: false)

      run = run_task

      expect(other.reload.capture_method).to be_nil
      expect(run.tallies['left_inheriting_store_setting']).to eq(1)
    end

    it 'is idempotent' do
      run_task
      Spree::MaintenanceTaskRun.update_all(status: 'succeeded')

      second = run_task

      expect(second.tick_count).to be_zero
      expect(payment_method.reload.capture_method).to eq('checkout')
    end
  end

  describe Spree::MaintenanceTasks::Upgrade::TaxStoreIds do
    it 'binds soft-deleted rows too' do
      rate = create(:tax_rate, store: store)
      rate.destroy
      rate.update_columns(store_id: nil)

      run = Spree::MaintenanceTasks::Start.call(
        task_name: described_class.name, initiated_via: 'cli', inline: true
      ).value.reload

      expect(rate.reload.store_id).to eq(store.id)
      expect(run.tallies['tax_rates']).to be >= 1
    end
  end

  describe Spree::MaintenanceTasks::Upgrade::RakeStep do
    before do
      require 'rake'
      Rake::Task.define_task('spec:aborting_step') { abort 'Set the pepper first.' }
      stub_const('SpecAbortingStep', Class.new(described_class) do
        def self.name = 'SpecAbortingStep'

        runs_rake_task 'spec:aborting_step'
      end)
      Spree.maintenance_tasks << 'SpecAbortingStep'
    end

    after do
      Spree.maintenance_tasks.delete('SpecAbortingStep')
      Rake::Task['spec:aborting_step'].clear
    end

    # Rake bodies stop with `abort`, which is not an ordinary error; left
    # alone it would leave the run marked running for good and the task
    # impossible to start again.
    it 'records a rake body that aborts as a failure' do
      run = nil

      expect do
        run = Spree::MaintenanceTasks::Start.call(task_name: 'SpecAbortingStep', initiated_via: 'cli', inline: true).value
      end.to output.to_stderr

      expect(run.reload).to be_errored
      expect(run.error_message).to eq('Set the pepper first.')
      expect(run).to be_resumable
    end
  end

  describe 'the walk' do
    before(:all) do
      require 'rake'
      Rake::Task.define_task(:environment) unless Rake::Task.task_defined?(:environment)
      load Spree::Core::Engine.root.join('lib', 'tasks', 'upgrade.rake')
    end

    # The documented way to re-run one step after fixing the data that stopped
    # it, rather than walking the whole manifest again.
    it 'runs a single step by id and records it' do
      runner = Spree::Upgrade::Runner.new(target_version: '6.0', step_id: 'migrate_capture_methods')

      expect { runner.call }.to change(Spree::MaintenanceTaskRun, :count).by(1)

      expect(Spree::MaintenanceTaskRun.last.task_name).
        to eq('Spree::MaintenanceTasks::Upgrade::CaptureMethods')
    end

    # The gem that owns an optional step is absent here, so the walk has to
    # skip it — an installation that never had the gem would otherwise fail on
    # a step that does not apply to it.
    it 'skips an optional step whose gem is not installed' do
      runner = Spree::Upgrade::Runner.new(target_version: '6.0', step_id: 'migrate_stripe_webhook_keys')

      expect { runner.call }.to output(/Skipping/).to_stdout
      expect(Spree::MaintenanceTaskRun.where(task_name: 'SpreeStripe::MaintenanceTasks::MigrateWebhookKeys')).to be_empty
    end

    # An inline run never slices itself, so anything short of success means
    # the step did not finish; the walk must stop rather than record the
    # release complete on top of it.
    it 'stops when a step did not succeed' do
      allow(Spree::MaintenanceTasks::RunJob).to receive(:perform_now)
      runner = Spree::Upgrade::Runner.new(target_version: '6.0', step_id: 'migrate_capture_methods')

      expect { runner.call }.to raise_error(SystemExit).and output(/did not finish/).to_stdout
    end

    it 'records a run for a rake-backed step of a released manifest' do
      runner = Spree::Upgrade::Runner.new(target_version: '5.6', step_id: 'taxon_store_id')

      expect { runner.call }.to change(Spree::MaintenanceTaskRun, :count).by(1)

      run = Spree::MaintenanceTaskRun.last
      expect(run.task_name).to eq('Spree::MaintenanceTasks::UpgradeStep')
      expect(run.arguments['step_id']).to eq('taxon_store_id')
    end
  end

  describe 'a step whose precondition fails' do
    it 'is refused before a run row is created' do
      allow(Spree::Store).to receive(:default).and_return(nil)

      result = Spree::MaintenanceTasks::Start.call(
        task_name: 'Spree::MaintenanceTasks::Upgrade::ReasonStoreIds', initiated_via: 'cli'
      )

      expect(result).to be_failure
      expect(result.error.to_s).to include('No default store')
      expect(Spree::MaintenanceTaskRun.count).to be_zero
    end
  end
end
