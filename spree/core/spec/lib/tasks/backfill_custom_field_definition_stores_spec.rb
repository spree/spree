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

  # The migration applies these itself and skips them only when it found rows
  # it could not fill. Restoring them is what this task exists to do — without
  # them the unique indexes constrain nothing, since SQL treats NULLs as
  # distinct.
  it 'reports the constraints it enforced' do
    create(:custom_field_definition, store: store, namespace: 'custom', key: 'material')

    # Already enforced by the migration, so the task finds nothing to do and
    # says so by staying silent about them rather than re-applying.
    expect { subject.invoke }.not_to output(/leaving it nullable/).to_stdout
  end

  # The branch that matters runs only on the schema the task exists to repair:
  # columns the migration left nullable because it found rows it could not
  # fill. Relaxing them here would be DDL, which MySQL commits implicitly and
  # so drops the savepoint the example runs inside — so the schema is reported
  # as nullable instead, and the constraint call is observed rather than
  # applied.
  #
  # `filter_key` is checked and `store_id` is not: RSpec stubs one call at a
  # time, and one column proves the branch runs.
  it 'enforces a constraint the migration left off' do
    connection = ActiveRecord::Base.connection
    nullable = connection.columns(Spree::CustomFieldDefinition.table_name).map do |column|
      column.name == 'filter_key' ? column.dup.tap { |c| c.instance_variable_set(:@null, true) } : column
    end
    allow(connection).to receive(:columns).and_call_original
    allow(connection).to receive(:columns).with(Spree::CustomFieldDefinition.table_name).and_return(nullable)
    allow(connection).to receive(:change_column_null).and_return(true)

    expect { subject.invoke }.to output(/Enforced NOT NULL on filter_key/).to_stdout

    expect(connection).to have_received(:change_column_null).
      with(Spree::CustomFieldDefinition.table_name, :filter_key, false)
  end

  it 'leaves a column alone while rows still cannot be filled' do
    connection = ActiveRecord::Base.connection
    nullable = connection.columns(Spree::CustomFieldDefinition.table_name).map do |column|
      column.name == 'filter_key' ? column.dup.tap { |c| c.instance_variable_set(:@null, true) } : column
    end
    allow(connection).to receive(:columns).and_call_original
    allow(connection).to receive(:columns).with(Spree::CustomFieldDefinition.table_name).and_return(nullable)
    allow(connection).to receive(:change_column_null).and_return(true)
    # The guard reads `exists?`; the backfill loop earlier in the task reads
    # `find_each` off the same query, so the double answers both.
    still_null = instance_double(ActiveRecord::Relation, exists?: true, find_each: nil)
    allow(Spree::CustomFieldDefinition).to receive(:where).and_call_original
    allow(Spree::CustomFieldDefinition).to receive(:where).with(filter_key: nil).and_return(still_null)

    expect { subject.invoke }.to output(/filter_key is still NULL/).to_stdout

    expect(connection).not_to have_received(:change_column_null).
      with(anything, :filter_key, false)
  end

  it 'refuses to run without a default store to assign' do
    allow(Spree::Store).to receive(:default).and_return(nil)

    expect { subject.invoke }.to raise_error(SystemExit).and output(/No default store/).to_stderr
  end
end
