require 'spec_helper'
require 'rake'

# Guards the contract `rake spree:upgrade` relies on: every manifest step is
# well-formed, ids are unique, and each required step's rake task — named
# directly or wrapped by its task class — is one spree_core actually defines. A task added without a manifest entry is caught
# by review; an entry pointing at a renamed or missing task is caught here.
describe 'spree:upgrade manifests' do
  manifests = Dir[Spree::Core::Engine.root.join('lib', 'spree', 'upgrades', '*', 'manifest.yml')].sort

  # Load core's rake files once, into a throwaway application, so tasks other
  # specs load individually don't get their actions registered twice. Those
  # specs may already have defined the files' constants, so redefining them
  # here is expected.
  before(:all) do
    original = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    silence_warnings { Dir[Spree::Core::Engine.root.join('lib', 'tasks', '*.rake')].sort.each { |file| load file } }
    @rake_app = Rake.application
  ensure
    Rake.application = original
  end

  it 'finds the manifests' do
    expect(manifests).not_to be_empty
  end

  manifests.each do |path|
    context File.basename(File.dirname(path)) do
      let(:manifest) { YAML.safe_load_file(path) }

      it 'gives every step an id, a name and either a task or a task class' do
        manifest['steps'].each do |step|
          runner = step.slice('task', 'task_class')

          expect(step).to include('id', 'name'), "malformed step: #{step.inspect}"
          expect(runner.size).to eq(1), "a step names a task or a task class, not both: #{step.inspect}"
          expect(step.values_at('id', 'name', *runner.keys)).to all(be_a(String).and(match(/\S/))),
                                                                 "manifest fields must be non-empty strings: #{step.inspect}"
        end
      end

      it 'has unique step ids' do
        ids = manifest['steps'].map { |step| step['id'] }
        expect(ids).to eq(ids.uniq)
      end

      it 'names a defined rake task for every required step' do
        # A task class wrapping a rake body names that body, which can be
        # renamed out from under it just as a manifest entry can.
        missing = manifest['steps'].reject { |step| step['optional'] }.
                  filter_map { |step| step['task'] || step['task_class'].constantize.try(:rake_task_name) }.
                  reject { |task| @rake_app.lookup(task) }

        expect(missing).to be_empty, "manifest references undefined rake tasks: #{missing.join(', ')}"
      end
    end
  end
end
