require 'spec_helper'
require 'rake'

describe 'spree:upgrade' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'upgrade.rake')
  end

  let(:manifests) do
    Spree::Upgrade.available_manifests.map do |entry|
      YAML.safe_load_file(File.join(entry[:dir], 'manifest.yml'))
    end
  end

  def step_ids_through(version)
    manifests
      .select { |manifest| Spree::Upgrade.compare(manifest['to'], version) <= 0 }
      .flat_map { |manifest| manifest['steps'].map { |step| step['id'] } }
  end

  def run_upgrade(**options)
    output = StringIO.new
    $stdout = output
    Spree::Upgrade::Runner.new(**options).call
    output.string
  ensure
    $stdout = STDOUT
  end

  before { allow(Spree).to receive(:version).and_return('6.0.0') }

  describe 'dry run without a target version' do
    it 'lists every backfill up to the installed version, the same set a real run executes' do
      output = run_upgrade(dry_run: true)

      expect(output).to include('Spree 5.4 → 5.5', 'Spree 5.5 → 5.6', 'Spree 5.6 → 6.0')
      expect(output).to include('Target: Spree 6.0.')
      step_ids_through('6.0').each { |step_id| expect(output).to include("[#{step_id}]") }
    end

    it 'executes nothing' do
      expect(Rake::Task).not_to receive(:[])

      expect(run_upgrade(dry_run: true)).to include('dry run — nothing executed')
    end
  end

  describe 'dry run with a target version' do
    it 'caps the plan at that version' do
      output = run_upgrade(dry_run: true, target_version: '5.5')

      expect(output).to include('Spree 5.4 → 5.5', 'Target: Spree 5.5.')
      expect(output).not_to include('Spree 5.5 → 5.6', 'Spree 5.6 → 6.0')
    end
  end

  describe 'real run' do
    it 'invokes every step the dry run listed' do
      invoked_tasks = []
      allow(Rake::Task).to receive(:task_defined?).and_return(true)
      allow(Rake::Task).to receive(:[]) do |task_name|
        instance_double(Rake::Task, reenable: nil).tap do |task|
          allow(task).to receive(:invoke) { invoked_tasks << task_name }
        end
      end

      run_upgrade

      expected_tasks = manifests
        .select { |manifest| Spree::Upgrade.compare(manifest['to'], '6.0') <= 0 }
        .flat_map { |manifest| manifest['steps'].map { |step| step['task'] } }
      expect(invoked_tasks).to eq(expected_tasks)
    end
  end
end
