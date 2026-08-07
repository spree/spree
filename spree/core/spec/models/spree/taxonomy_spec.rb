require 'spec_helper'

describe Spree::Taxonomy, type: :model do
  # Taxonomy is data-only in 6.0 — it exists so the 5.6 -> 6.0 upgrade task can
  # read existing rows to backfill category store_id. It is dropped in 6.1.
  let(:store) { @default_store }

  it 'reads its store and its categories for the upgrade task' do
    taxonomy = create(:taxonomy, store: store)
    category = create(:taxon, taxonomy: taxonomy, parent: taxonomy.root)

    expect(taxonomy.store).to eq(store)
    expect(taxonomy.taxons).to include(taxonomy.root, category)
  end

  it 'no longer manages a root category or syncs its name' do
    taxonomy = create(:taxonomy, name: 'Clothing', store: store)
    root = taxonomy.root

    expect { taxonomy.update!(name: 'Soft Goods') }.not_to change { root.reload.name }
  end
end
