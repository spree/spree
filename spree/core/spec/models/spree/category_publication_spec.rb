require 'spec_helper'

RSpec.describe Spree::CategoryPublication, type: :model do
  let(:store) { @default_store }
  let(:category) { create(:category, :unpublished, store: store) }
  let(:channel) { store.default_channel }

  describe 'validations' do
    it 'refuses a channel of another store' do
      publication = build(:category_publication, category: category, channel: create(:channel, store: create(:store)))

      expect(publication).not_to be_valid
      expect(publication.errors[:channel]).to be_present
    end

    it 'refuses a second publication on the same channel' do
      create(:category_publication, category: category, channel: channel)

      expect(build(:category_publication, category: category, channel: channel)).not_to be_valid
    end
  end

  describe 'events' do
    it 'publishes category.published and category.unpublished with the channel' do
      allow(category).to receive(:publish_event)
      publication = create(:category_publication, category: category, channel: channel)
      publication.destroy!

      expect(category).to have_received(:publish_event).with('category.published', nil, { channel_id: channel.prefixed_id })
      expect(category).to have_received(:publish_event).with('category.unpublished', nil, { channel_id: channel.prefixed_id })
    end
  end
end
