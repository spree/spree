require 'spec_helper'

RSpec.describe Spree::MaintenanceTask do
  describe 'the registry' do
    after { Spree.maintenance_tasks.delete('RegistrySpecTask') }

    it 'lists the tasks core ships' do
      expect(described_class.registered_classes).to include(Spree::MaintenanceTasks::Upgrade::BackfillOrderMarkets)
    end

    it 'resolves class names registered by an extension' do
      stub_const('RegistrySpecTask', Class.new(described_class) { def self.name = 'RegistrySpecTask' })
      Spree.maintenance_tasks << 'RegistrySpecTask'

      expect(described_class.find_registered('RegistrySpecTask')).to eq(RegistrySpecTask)
    end

    # A class that merely exists is not an operator-runnable task; only
    # registration makes it one.
    it 'does not resolve an unregistered class' do
      stub_const('UnregisteredTask', Class.new(described_class) { def self.name = 'UnregisteredTask' })

      expect(described_class.find_registered('UnregisteredTask')).to be_nil
    end

    it 'ignores a registered name whose class has gone away' do
      Spree.maintenance_tasks << 'RegistrySpecTask'

      expect { described_class.registered_classes }.not_to raise_error
      expect(described_class.find_registered('RegistrySpecTask')).to be_nil
    end
  end

  describe 'short names' do
    it 'names a task by its demodulized, underscored class' do
      expect(Spree::MaintenanceTasks::Upgrade::CaptureMethods.api_type).to eq('capture_methods')
    end

    it 'finds a registered task by its short name but not by its class name' do
      expect(described_class.find_by_api_type('capture_methods')).to eq(Spree::MaintenanceTasks::Upgrade::CaptureMethods)
      expect(described_class.find_by_api_type('Spree::MaintenanceTasks::Upgrade::CaptureMethods')).to be_nil
    end

    # The short name is the only identifier the API has, so two registered
    # tasks sharing one would make one of them unreachable.
    it 'is unique across the tasks core ships' do
      names = described_class.registered_classes.map(&:api_type)

      expect(names.size).to eq(names.uniq.size)
    end
  end

  describe 'declarations' do
    it 'defaults to a batch size' do
      expect(described_class.batch_size).to eq(described_class::DEFAULT_BATCH_SIZE)
    end

    it 'does not support dry run unless the task says so' do
      plain = Class.new(described_class) { def self.name = 'PlainTask' }
      previewable = Class.new(described_class) do
        def self.name = 'PreviewableTask'
        supports_dry_run
      end

      expect(plain.dry_run_supported).to be(false)
      expect(previewable.dry_run_supported).to be(true)
    end

  end

  describe 'the default instance surface' do
    it 'refuses to run without a collection' do
      task = Class.new(described_class) { def self.name = 'NoCollectionDefined' }.new

      expect { task.collection }.to raise_error(NotImplementedError)
    end

    it 'accumulates tallies' do
      task = Class.new(described_class) { def self.name = 'TallyTask' }.new
      task.tally(:updated)
      task.tally(:updated, 3)

      expect(task.tallies['updated']).to eq(4)
    end
  end
end
