require 'spec_helper'
require 'rake'

describe 'spree:collections' do
  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'collections.rake')
  end

  let(:store) { @default_store }

  describe 'backfill_publications' do
    subject(:task) { Rake::Task['spree:collections:backfill_publications'] }

    before { task.reenable }

    let!(:pos) { create(:channel, store: store, name: 'POS', code: 'pos') }
    let!(:retired) { create(:channel, store: store, name: 'Retired', code: 'retired', active: false) }
    let!(:unpublished) { create(:collection, :unpublished, store: store) }
    let!(:published_on_pos) do
      create(:collection, :unpublished, store: store).tap { |collection| pos.add_collections(collection.id) }
    end

    it 'puts collections without a publication on every active channel' do
      expect { task.invoke }.to output(/Published 1 collection/).to_stdout

      expect(unpublished.reload.channels).to contain_exactly(store.default_channel, pos)
    end

    it 'leaves collections that already have a publication alone' do
      expect { task.invoke }.to output.to_stdout

      expect(published_on_pos.reload.channels).to contain_exactly(pos)
    end
  end

  describe 'backfill_membership_sources' do
    subject(:task) { Rake::Task['spree:collections:backfill_membership_sources'] }

    before { task.reenable }

    let(:automatic) { create(:automatic_collection, store: store) }
    let(:manual) { create(:collection, store: store) }
    let!(:legacy_rule_row) { create(:product_collection, collection: automatic).tap { |row| row.update_columns(source: nil) } }
    let!(:legacy_manual_row) { create(:product_collection, collection: manual).tap { |row| row.update_columns(source: nil) } }
    let!(:named_row) { create(:product_collection, collection: automatic) }

    it 'marks rows of automatic collections as rule and the rest as manual' do
      expect { task.invoke }.to output(/1 membership\(s\) as rule and 1 as manual/).to_stdout

      expect(legacy_rule_row.reload.source).to eq('rule')
      expect(legacy_manual_row.reload.source).to eq('manual')
      expect(named_row.reload.source).to eq('manual')
    end
  end
end
