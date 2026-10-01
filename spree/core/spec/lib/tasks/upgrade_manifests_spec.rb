require 'spec_helper'
require 'rake'

# Guards the contract `rake spree:upgrade` relies on: every manifest step is
# well-formed, ids are unique, and each required step names a rake task that
# spree_core actually defines. A task added without a manifest entry is caught
# by review; an entry pointing at a renamed or missing task is caught here.
describe 'spree:upgrade manifests' do
  manifests = Dir[Spree::Core::Engine.root.join('lib', 'spree', 'upgrades', '*', 'manifest.yml')].sort

  # Load core's rake files into a throwaway application so tasks other specs
  # load individually don't get their actions registered twice.
  let(:rake_app) do
    original = Rake.application
    Rake.application = Rake::Application.new
    Rake::Task.define_task(:environment)
    Dir[Spree::Core::Engine.root.join('lib', 'tasks', '*.rake')].sort.each { |file| load file }
    Rake.application
  ensure
    Rake.application = original
  end

  it 'finds the manifests' do
    expect(manifests).not_to be_empty
  end

  manifests.each do |path|
    context File.basename(File.dirname(path)) do
      let(:manifest) { YAML.safe_load_file(path) }

      it 'gives every step an id, name and task' do
        manifest['steps'].each do |step|
          expect(step).to include('id', 'name', 'task'), "malformed step: #{step.inspect}"
          expect(step.values_at('id', 'name', 'task')).to all(be_a(String).and(match(/\S/))),
                                                          "manifest fields must be non-empty strings: #{step.inspect}"
        end
      end

      it 'has unique step ids' do
        ids = manifest['steps'].map { |step| step['id'] }
        expect(ids).to eq(ids.uniq)
      end

      it 'names a defined rake task for every required step' do
        missing = manifest['steps'].reject { |step| step['optional'] }.
                  map { |step| step['task'] }.
                  reject { |task| rake_app.lookup(task) }

        expect(missing).to be_empty, "manifest references undefined rake tasks: #{missing.join(', ')}"
      end
    end
  end
end
