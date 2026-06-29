require 'spec_helper'
require 'rake'

describe 'spree:taxons:backfill_store_id' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:taxons:backfill_store_id' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'taxons.rake')
  end

  before { subject.reenable }

  let!(:store) { Spree::Store.default || create(:store, default: true) }

  # ensure_store stamps store_id on create, so null it to reproduce a row
  # created before the column existed.
  def downgrade!(taxon)
    taxon.update_columns(store_id: nil)
    taxon
  end

  context 'taxonomy-backed taxon' do
    let(:taxonomy) { create(:taxonomy, store: store) }
    let!(:taxon) { downgrade!(create(:taxon, taxonomy: taxonomy)) }

    it 'backfills store_id from the taxonomy' do
      expect { subject.invoke }.to change { taxon.reload.store_id }.from(nil).to(store.id)
    end
  end

  context 'taxonomy-less taxons in a parent chain' do
    # Root keeps its store (resolved via the taxonomy pass or pre-existing);
    # descendants must inherit it down the chain.
    let!(:root) { Spree::Category.create!(name: 'Root', store: store) }
    let!(:mid) { downgrade!(Spree::Category.create!(name: 'Mid', parent: root)) }
    let!(:leaf) { downgrade!(Spree::Category.create!(name: 'Leaf', parent: mid)) }

    it 'resolves every level from the nearest resolved ancestor' do
      subject.invoke

      expect(mid.reload.store_id).to eq(store.id)
      expect(leaf.reload.store_id).to eq(store.id)
    end

    it 'is idempotent — a re-run changes nothing' do
      subject.invoke
      subject.reenable
      expect { subject.invoke }.not_to change { [mid.reload.store_id, leaf.reload.store_id] }
    end
  end

  context 'when nothing needs backfilling' do
    # Every taxon already has a store_id — the task must still run cleanly.
    # The buggy join-update raised at SQL-parse time even with zero matching rows.
    let!(:taxon) { create(:taxon, taxonomy: create(:taxonomy, store: store)) }

    it 'is a safe no-op' do
      expect { subject.invoke }.not_to raise_error
    end
  end

  context 'taxonomy-less root with no resolvable ancestor' do
    # No taxonomy and no parent to inherit from — the backfill has no store to
    # resolve it against, so the row is intentionally left untouched rather than
    # defaulted (ensure_store's current-store fallback needs request context the
    # task doesn't have).
    let!(:orphan) { downgrade!(Spree::Category.create!(name: 'Orphan', store: store)) }

    it 'leaves store_id nil' do
      expect { subject.invoke }.not_to change { orphan.reload.store_id }.from(nil)
    end
  end
end
