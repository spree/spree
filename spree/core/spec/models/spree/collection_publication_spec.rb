require 'spec_helper'

RSpec.describe Spree::CollectionPublication, type: :model do
  let(:store) { @default_store }
  let(:collection) { create(:collection, :unpublished, store: store) }
  let(:channel) { store.default_channel }

  describe '.published' do
    it 'includes open windows and leaves out scheduled and ended ones' do
      live = create(:collection_publication, collection: collection, channel: channel)
      scheduled = create(:collection_publication, collection: create(:collection, :unpublished), channel: channel, published_at: 1.day.from_now)
      ended = create(:collection_publication, collection: create(:collection, :unpublished), channel: channel,
                                              published_at: 2.days.ago, unpublished_at: 1.day.ago)

      expect(described_class.published).to include(live)
      expect(described_class.published).not_to include(scheduled, ended)
    end
  end

  describe 'validations' do
    it 'refuses a channel of another store' do
      other_channel = create(:channel, store: create(:store))
      publication = build(:collection_publication, collection: collection, channel: other_channel)

      expect(publication).not_to be_valid
      expect(publication.errors[:channel]).to be_present
    end

    it 'refuses a window that ends before it starts' do
      publication = build(:collection_publication, collection: collection, channel: channel,
                                                   published_at: 1.day.from_now, unpublished_at: 1.hour.from_now)

      expect(publication).not_to be_valid
    end
  end

  describe 'events' do
    it 'publishes collection.published and collection.unpublished with the channel' do
      allow(collection).to receive(:publish_event)
      publication = create(:collection_publication, collection: collection, channel: channel)
      publication.destroy!

      expect(collection).to have_received(:publish_event).with('collection.published', nil, { channel_id: channel.prefixed_id })
      expect(collection).to have_received(:publish_event).with('collection.unpublished', nil, { channel_id: channel.prefixed_id })
    end
  end
end
