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

    run = start(admin_user: admin, store: store, initiated_via: 'dashboard').value

    expect(run.admin_user).to eq(admin)
    expect(run.store).to eq(store)
    expect(run.initiated_via).to eq('dashboard')
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

  describe 'preconditions' do
    before do
      stub_const('GuardedTask', Class.new(Spree::MaintenanceTask) do
        def self.name = 'GuardedTask'
        precondition('the column this task fills has not been added yet') { false }
        def collection = Spree::Product.order(:id)
        def process(product) = nil
      end)
      Spree.maintenance_tasks << 'GuardedTask'
    end

    after { Spree.maintenance_tasks.delete('GuardedTask') }

    it 'refuses the run and says what is missing' do
      result = described_class.call(task_name: 'GuardedTask')

      expect(result).to be_failure
      expect(result.error.to_s).to include('has not been added yet')
      expect(Spree::MaintenanceTaskRun.count).to be_zero
    end
  end
end
