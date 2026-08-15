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

    it 'registers every task class it names' do
      manifest['steps'].each do |step|
        expect(Spree::MaintenanceTask.find_registered(step['task_class'])).
          to be_present, "#{step['id']} names #{step['task_class']}, which is not registered"
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
