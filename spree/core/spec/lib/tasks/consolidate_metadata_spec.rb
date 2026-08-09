require 'spec_helper'
require 'rake'

describe 'metadata consolidation' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'consolidate_metadata.rake')
  end

  let(:connection) { ActiveRecord::Base.connection }
  let(:table_name) { 'spree_legacy_metadata_fixtures' }
  let(:quoted_table) { connection.quote_table_name(table_name) }

  # The real tables are consolidated by the migration, so both the migration's
  # merge and the safety-net rake task are exercised against a synthetic table
  # still carrying the pre-6.0 pair — the state an out-of-band install is in.
  before do
    connection.drop_table table_name, if_exists: true
    connection.create_table table_name do |t|
      if t.respond_to?(:jsonb)
        t.jsonb :public_metadata
        t.jsonb :private_metadata
      else
        t.json :public_metadata
        t.json :private_metadata
      end
    end
  end

  after do
    connection.drop_table table_name, if_exists: true
    connection.drop_table :spree_consolidated_metadata_tables, if_exists: true
  end

  def insert_row(public_metadata:, private_metadata:)
    connection.exec_insert(
      "INSERT INTO #{quoted_table} (public_metadata, private_metadata) VALUES " \
      "(#{connection.quote(public_metadata&.to_json)}, #{connection.quote(private_metadata&.to_json)})"
    )
    connection.select_values("SELECT id FROM #{quoted_table} ORDER BY id DESC").first
  end

  def merged_metadata_for(id)
    value = connection.select_value(
      "SELECT private_metadata FROM #{quoted_table} WHERE id = #{connection.quote(id)}"
    )
    Spree::MetadataConsolidator.parse(value)
  end

  shared_examples 'a metadata merge' do
    it 'merges disjoint keys from both columns' do
      id = insert_row(public_metadata: { 'pub' => 'p' }, private_metadata: { 'priv' => 'q' })

      merge

      expect(merged_metadata_for(id)).to eq('pub' => 'p', 'priv' => 'q')
    end

    it 'keeps the private value when a key exists in both columns' do
      id = insert_row(public_metadata: { 'k' => 'public' }, private_metadata: { 'k' => 'private' })

      merge

      expect(merged_metadata_for(id)).to eq('k' => 'private')
    end

    it 'copies public metadata onto rows that have no private metadata' do
      id = insert_row(public_metadata: { 'pub' => 'p' }, private_metadata: nil)

      merge

      expect(merged_metadata_for(id)).to eq('pub' => 'p')
    end

    it 'leaves rows with an empty or missing public metadata untouched' do
      empty = insert_row(public_metadata: {}, private_metadata: { 'only' => 'private' })
      missing = insert_row(public_metadata: nil, private_metadata: { 'only' => 'private' })

      merge

      expect(merged_metadata_for(empty)).to eq('only' => 'private')
      expect(merged_metadata_for(missing)).to eq('only' => 'private')
    end

    it 'is idempotent' do
      id = insert_row(public_metadata: { 'k' => 'public' }, private_metadata: { 'k' => 'private' })

      merge
      merge

      expect(merged_metadata_for(id)).to eq('k' => 'private')
    end

    # The columns are untyped JSON, so an application could have stored an array or
    # a scalar. Those are unusable as metadata but must not abort the run.
    it 'discards non-hash values rather than failing' do
      array_public = insert_row(public_metadata: %w[a b], private_metadata: { 'priv' => 'kept' })
      scalar_public = insert_row(public_metadata: 42, private_metadata: { 'priv' => 'kept' })
      array_private = insert_row(public_metadata: { 'pub' => 'kept' }, private_metadata: %w[a b])

      expect { merge }.not_to raise_error

      expect(merged_metadata_for(array_public)).to eq('priv' => 'kept')
      expect(merged_metadata_for(scalar_public)).to eq('priv' => 'kept')
      expect(merged_metadata_for(array_private)).to eq('pub' => 'kept')
    end
  end

  # The path every upgrading install actually takes.
  describe 'the migration' do
    let(:migration) do
      require Spree::Core::Engine.root.join('db', 'migrate', '20260809120001_consolidate_metadata_columns.rb')
      ConsolidateMetadataColumns.new.tap { |m| m.verbose = false }
    end

    def merge
      migration.send(:merge_public_metadata_into_private, table_name)
    end

    # Runs the real `up` against the fixture alone, so the registry it writes — the
    # thing `down` reads — is populated for real rather than stubbed.
    def consolidate_fixture
      allow(migration).to receive(:legacy_tables).and_return([table_name])
      migration.up
    end

    def with_rollback_override
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('FORCE_METADATA_ROLLBACK').and_return('true')
      yield
    end

    it_behaves_like 'a metadata merge'

    # These were born with a single `metadata` column. Nothing names them: they are
    # excluded because they have no `public_metadata` to pair with, and because the
    # migration never recorded renaming them.
    it 'never touches tables that were born with a single metadata column' do
      native_tables = %w[spree_collections spree_carts spree_returns spree_tax_lines spree_customers]

      expect(migration.send(:legacy_tables)).not_to include(*native_tables)
      expect(migration.send(:consolidated_tables)).not_to include(*native_tables)
    end

    # active_storage_blobs carries its own unrelated `metadata` column. Selecting
    # rollback targets by shape would sweep it up and rename Rails' column, breaking
    # every attachment; the registry can only ever name tables this migration renamed.
    it 'never touches a non-Spree table that happens to have a metadata column' do
      skip 'Active Storage not installed' unless connection.table_exists?(:active_storage_blobs)

      expect(migration.send(:legacy_tables)).not_to include('active_storage_blobs')
      expect(migration.send(:consolidated_tables)).not_to include('active_storage_blobs')
    end

    # The full `up` pass, not just the merge helper: the fixture table goes in
    # carrying the legacy pair and comes out with one column holding merged values.
    # Scoped to the fixture so the run doesn't consolidate the whole test schema.
    it 'merges and consolidates the columns in one pass' do
      id = insert_row(public_metadata: { 'pub' => 'kept', 'clash' => 'public' },
                      private_metadata: { 'clash' => 'private', 'priv' => 'kept' })

      allow(migration).to receive(:legacy_tables).and_return([table_name])
      migration.up

      columns = connection.columns(table_name).map(&:name)
      expect(columns).to include('metadata')
      expect(columns).not_to include('public_metadata', 'private_metadata')

      value = connection.select_value("SELECT metadata FROM #{quoted_table} WHERE id = #{connection.quote(id)}")
      expect(Spree::MetadataConsolidator.parse(value)).to eq(
        'pub' => 'kept', 'priv' => 'kept', 'clash' => 'private'
      )
    end

    it 'refuses to roll back without an explicit override' do
      consolidate_fixture

      expect { migration.down }.to raise_error(ActiveRecord::IrreversibleMigration, /not recoverable/)
      expect(connection.columns(table_name).map(&:name)).to include('metadata')
    end

    it 'rolls back the column shape when the override is set' do
      consolidate_fixture

      with_rollback_override { migration.down }

      columns = connection.columns(table_name).map(&:name)
      expect(columns).to include('public_metadata', 'private_metadata')
      expect(columns).not_to include('metadata')
    end

    # Rollback reverses only what `up` recorded, so a table the migration never
    # touched keeps its single `metadata` column even under the override.
    it 'leaves a table it never consolidated alone on rollback' do
      consolidate_fixture
      connection.create_table(:spree_native_metadata_fixtures) do |t|
        t.respond_to?(:jsonb) ? t.jsonb(:metadata) : t.json(:metadata)
      end

      with_rollback_override { migration.down }

      expect(connection.columns(:spree_native_metadata_fixtures).map(&:name)).to eq(%w[id metadata])
    ensure
      connection.drop_table(:spree_native_metadata_fixtures, if_exists: true)
    end
  end

  # The safety net for schemas changed out of band.
  describe 'the rake task' do
    def merge
      task = Rake::Task['spree:upgrade:consolidate_metadata']
      task.reenable
      original_stdout = $stdout.dup
      $stdout.reopen(File::NULL, 'w')
      task.invoke
    ensure
      $stdout.reopen(original_stdout)
    end

    it_behaves_like 'a metadata merge'
  end
end
