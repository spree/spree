require 'spec_helper'

RSpec.describe Spree::MaintenanceTasks::Start do
  let(:store) { @default_store }

  before do
    stub_const('StartSpecTask', Class.new(Spree::MaintenanceTask) do
      supports_dry_run
      def self.name = 'StartSpecTask'
      attribute :label, :string
      validates :label, presence: true
      def collection = Spree::Product.order(:id)
      def process(product) = nil
    end)
    Spree.maintenance_tasks << 'StartSpecTask'
  end

  after { Spree.maintenance_tasks.delete('StartSpecTask') }

  def start(**overrides)
    described_class.call(task_name: 'StartSpecTask', arguments: { 'label' => 'x' }, **overrides)
  end

  it 'creates a run and enqueues the runner' do
    expect { start }.to have_enqueued_job(Spree::MaintenanceTasks::RunJob)

    expect(Spree::MaintenanceTaskRun.last).to be_enqueued
  end

  it 'records who fired it and from where' do
    admin = create(:admin_user)

    run = start(admin_user: admin, initiated_via: 'dashboard').value

    expect(run.admin_user).to eq(admin)
    expect(run.initiated_via).to eq('dashboard')
  end

  it 'finds a task by its short name' do
    run = described_class.call(api_type: 'start_spec_task', arguments: { 'label' => 'x' }).value

    expect(run.task_name).to eq('StartSpecTask')
  end

  it 'does not take a class name as a short name' do
    result = described_class.call(api_type: 'StartSpecTask', arguments: { 'label' => 'x' })

    expect(result).to be_failure
  end

  it 'refuses a task that is not registered' do
    result = described_class.call(task_name: 'Nope::Task')

    expect(result).to be_failure
    expect(result.error.to_s).to include('not a registered maintenance task')
  end

  it 'refuses arguments the task rejects' do
    result = described_class.call(task_name: 'StartSpecTask', arguments: {})

    expect(result).to be_failure
    expect(result.error.to_h[:label]).to be_present
  end

  # Two runs of one task would race each other over the same records, and
  # their cursors would leapfrog.
  # A typo or a stale client must get told which parameter is wrong, and a
  # key naming one of the task's own internals must never reach it.
  it 'refuses an argument the task does not declare' do
    result = described_class.call(task_name: 'StartSpecTask', arguments: { 'label' => 'x', 'run' => 'x' })

    expect(result).to be_failure
    expect(result.error.to_s).to include('no parameter named run')
    expect(Spree::MaintenanceTaskRun.count).to eq(0)
  end

  describe 'an upgrade step from a release already completed' do
    before { Spree::UpgradeRecord.stamp!('6.0', source: 'walk') }

    let(:step) { Spree::Upgrade.find_step('migrate_capture_methods') }

    # Re-running a completed conversion is how an upgrade damages data; the
    # dashboard hides these steps, and the API has to refuse them too.
    it 'is refused from the API and the dashboard' do
      %w[api dashboard].each do |initiated_via|
        result = described_class.call(task_name: step['task_class'], initiated_via: initiated_via)

        expect(result).to be_failure, "#{initiated_via} was allowed"
      end
    end

    it 'is refused through the generic step runner too' do
      released = Spree::Upgrade.superseded_steps.find { |candidate| candidate['task'] }
      result = described_class.call(task_name: 'Spree::MaintenanceTasks::UpgradeStep',
                                    arguments: { 'step_id' => released['id'] }, initiated_via: 'api')

      expect(result).to be_failure
    end

    # The command line is where an operator deliberately re-runs a step.
    it 'stays available from the command line' do
      result = described_class.call(task_name: step['task_class'], initiated_via: 'cli')

      expect(result).to be_success
    end
  end

  it 'refuses a second run while one is in flight' do
    start

    result = start

    expect(result).to be_failure
    expect(result.error.to_s).to include('already running')
  end

  it 'allows a new run once the previous one finished' do
    start
    Spree::MaintenanceTaskRun.last.update!(status: 'succeeded')

    expect(start).to be_success
  end

  describe 'dry run' do
    it 'is recorded when the task supports it' do
      expect(start(dry_run: true).value).to be_dry_run
    end

    # A task that ignores dry_run? writes for real; recording the run as a
    # preview would misrepresent what happened.
    it 'is refused for a task that does not support it' do
      stub_const('NoDryRunTask', Class.new(Spree::MaintenanceTask) do
        def self.name = 'NoDryRunTask'
        def collection = Spree::Product.order(:id)
        def process(product) = nil
      end)
      Spree.maintenance_tasks << 'NoDryRunTask'

      run = described_class.call(task_name: 'NoDryRunTask', dry_run: true).value

      expect(run).not_to be_dry_run
      Spree.maintenance_tasks.delete('NoDryRunTask')
    end
  end
end
