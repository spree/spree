require 'spec_helper'

RSpec.describe Spree::Category, 'channel publishing', type: :model do
  let(:store) { @default_store }
  let(:channel) { store.default_channel }
  let!(:pos) { create(:channel, store: store, code: 'pos', name: 'POS') }

  describe 'on create' do
    it 'goes live on every active channel of its store' do
      create(:channel, store: store, code: 'closed', name: 'Closed', active: false)

      expect(create(:category, store: store).channels).to contain_exactly(channel, pos)
    end

    it 'takes the publications set instead when one is given' do
      category = create(:category, store: store, publications: [{ channel_id: pos.prefixed_id }])

      expect(category.channels).to contain_exactly(pos)
    end

    it 'announces each channel once the record commits', events: true do
      Spree::Events.reset!
      published = []
      Spree::Events.subscribe('category.published', async: false) { |event| published << event.metadata['channel_id'] }
      Spree::Events.activate!

      create(:category, store: store)

      expect(published).to contain_exactly(channel.prefixed_id, pos.prefixed_id)
    ensure
      Spree::Events.reset!
    end
  end

  describe '.published_on' do
    let!(:parent) { create(:category, store: store) }
    let!(:child) { create(:category, store: store, parent: parent) }
    let!(:grandchild) { create(:category, store: store, parent: child) }

    it 'returns the categories published on the channel' do
      expect(described_class.published_on(channel)).to include(parent, child, grandchild)
    end

    it 'hides the subtree of a category unpublished from the channel' do
      child.update!(publications: [{ channel_id: pos.prefixed_id }])

      expect(described_class.published_on(channel)).to include(parent)
      expect(described_class.published_on(channel)).not_to include(child, grandchild)
      expect(described_class.published_on(pos)).to include(parent, child, grandchild)
    end

    it 'hides the subtree while an ancestor is scheduled' do
      parent.update!(publications: [{ channel_id: channel.prefixed_id, published_at: 1.day.from_now }])

      expect(described_class.published_on(channel)).not_to include(parent, child, grandchild)
    end

    it 'leaves out categories of other channels and stores' do
      expect(described_class.published_on(create(:channel, store: create(:store)))).to be_empty
      expect(described_class.published_on(nil)).to be_empty
    end
  end

  describe '#publications=' do
    let(:category) { create(:category, store: store) }

    it 'unpublishes the channels left out' do
      category.update!(publications: [{ channel_id: pos.prefixed_id }])

      expect(category.reload.channels).to contain_exactly(pos)
    end

    it 'ignores a channel of another store' do
      category.update!(publications: [{ channel_id: create(:channel, store: create(:store)).prefixed_id }])

      expect(category.reload.publications).to be_empty
    end

    it 'refuses a row without a channel and keeps the publications' do
      expect(category.update(publications: [{ published_at: 1.day.from_now }])).to be(false)
      expect(category.reload.channels).to contain_exactly(channel, pos)
    end
  end

  describe '.backfill_publications' do
    it 'publishes categories without a publication on every active channel, once' do
      unpublished = create(:category, :unpublished, store: store)
      pos_only = create(:category, store: store, publications: [{ channel_id: pos.prefixed_id }])

      expect(described_class.backfill_publications).to eq(1)
      expect(unpublished.reload.channels).to contain_exactly(channel, pos)
      expect(pos_only.reload.channels).to contain_exactly(pos)
      expect(described_class.backfill_publications).to eq(0)
    end
  end
end
