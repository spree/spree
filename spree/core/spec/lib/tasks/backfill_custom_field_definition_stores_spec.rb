require 'spec_helper'
require 'rake'

# The task is the recovery path for an install whose migration ran with no
# store present, leaving rows unowned and the NOT NULL constraints unapplied.
# That shape cannot be built here — the constraints are on, and relaxing them
# is DDL, which MySQL commits implicitly and so drops the savepoint the example
# runs inside. What is testable without them is the behaviour every install
# sees: the task is a no-op on a migrated schema, and it refuses to run with no
# store to assign.
describe 'spree:upgrade:backfill_custom_field_definition_stores' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:backfill_custom_field_definition_stores' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'backfill_custom_field_definition_stores.rake')
  end

  before { subject.reenable }

  let(:store) { Spree::Store.default }

  it 'reports nothing to do on a migrated schema' do
    create(:custom_field_definition, store: store, namespace: 'custom', key: 'material')

    expect { subject.invoke }.to output(/Assigned 0 .*Backfilled filter_key on 0/m).to_stdout
  end

  it 'leaves every definition exactly as it found it' do
    other_store = create(:store)
    mine = create(:custom_field_definition, store: store, namespace: 'custom', key: 'material')
    theirs = create(:custom_field_definition, store: other_store, namespace: 'custom', key: 'supplier')

    subject.invoke

    expect(mine.reload.store).to eq(store)
    expect(mine.reload[:filter_key]).to eq('cf_custom_material')
    expect(theirs.reload.store).to eq(other_store)
  end

  it 'refuses to run without a default store to assign' do
    allow(Spree::Store).to receive(:default).and_return(nil)

    expect { subject.invoke }.to raise_error(SystemExit).and output(/No default store/).to_stderr
  end
end
