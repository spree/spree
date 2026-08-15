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

  describe 'the parameter schema' do
    before do
      stub_const('SchemaSpecTask', Class.new(described_class) do
        def self.name = 'SchemaSpecTask'
        attribute :label, :string
        attribute :batch_size, :integer, default: 100
        attribute :mode, :string
        attribute :token, :string
        validates :label, presence: true
        validates :mode, inclusion: { in: %w[fast thorough] }
        mask_attribute :token
      end)
    end

    def field(name) = SchemaSpecTask.parameters_schema.find { |entry| entry[:name] == name }

    it 'reports each attribute with its type' do
      expect(field('label')[:type]).to eq('string')
      expect(field('batch_size')[:type]).to eq('integer')
    end

    it 'marks attributes a presence validator requires' do
      expect(field('label')[:required]).to be(true)
      expect(field('mode')[:required]).to be(false)
    end

    # An inclusion validator is what turns a parameter into a select rather
    # than a free-text field.
    it 'exposes the permitted values of an inclusion validator' do
      expect(field('mode')[:options]).to eq(%w[fast thorough])
      expect(field('label')[:options]).to be_nil
    end

    it 'carries defaults through' do
      expect(field('batch_size')[:default]).to eq(100)
    end

    it 'flags masked attributes so a form never echoes them back' do
      expect(field('token')[:masked]).to be(true)
      expect(field('label')[:masked]).to be(false)
    end
  end

  describe 'declarations' do
    it 'defaults to a batch size and a run time limit' do
      expect(described_class.batch_size).to eq(described_class::DEFAULT_BATCH_SIZE)
      expect(described_class.run_time_limit).to eq(described_class::DEFAULT_MAX_RUN_TIME)
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

    it 'resolves a description given as a translation key' do
      expect(Spree::MaintenanceTasks::Upgrade::BackfillOrderMarkets.resolved_description).
        to eq('Assign a market to orders placed before markets existed')
    end

    it 'leaves a plain-text description alone' do
      task = Class.new(described_class) do
        def self.name = 'PlainDescriptionTask'
        description 'Just words'
      end

      expect(task.resolved_description).to eq('Just words')
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
