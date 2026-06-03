require 'spec_helper'

RSpec.describe Spree::ProductPublication, type: :model do
  let(:store) { @default_store }
  let(:channel) { store.default_channel }
  let(:product) { create(:product, store: store) }

  let(:other_store) { create(:store, default: false, code: 'other') }
  let(:other_channel) { other_store.default_channel }
  # A second channel on the *same* store as +product+, so we can build a
  # second publication against the same product without colliding with the
  # default-channel publication the +:product+ factory attached for test
  # convenience.
  let(:secondary_channel) { create(:channel, store: store, code: 'pos', name: 'POS') }

  describe 'validations' do
    it 'is valid with product and channel' do
      publication = build(:product_publication, product: product, channel: secondary_channel)
      expect(publication).to be_valid
    end

    it 'enforces uniqueness per (product, channel)' do
      duplicate = build(:product_publication, product: product, channel: channel)
      expect(duplicate).not_to be_valid
    end

    it 'rejects unpublished_at before published_at' do
      publication = build(
        :product_publication,
        product: product, channel: secondary_channel,
        published_at: 1.day.from_now, unpublished_at: 1.hour.from_now
      )
      expect(publication).not_to be_valid
      expect(publication.errors[:unpublished_at]).to be_present
    end
  end

  describe '#store delegation' do
    it 'returns the channel.store' do
      publication = build(:product_publication, product: product, channel: secondary_channel)
      expect(publication.store).to eq(store)
      expect(publication.store_id).to eq(store.id)
    end
  end

  describe '.published' do
    it 'includes publications with null dates' do
      publication = create(:product_publication, product: product, channel: secondary_channel)
      expect(described_class.published).to include(publication)
    end

    it 'excludes publications with future published_at' do
      publication = create(
        :product_publication,
        product: product, channel: secondary_channel,
        published_at: 1.day.from_now
      )
      expect(described_class.published).not_to include(publication)
    end

    it 'excludes publications with past unpublished_at' do
      publication = create(
        :product_publication,
        product: product, channel: secondary_channel,
        published_at: 2.days.ago, unpublished_at: 1.day.ago
      )
      expect(described_class.published).not_to include(publication)
    end
  end

  describe '#published?' do
    it 'is true when dates are nil' do
      expect(build(:product_publication, product: product, channel: secondary_channel).published?).to be true
    end

    it 'is false when published_at is in the future' do
      publication = build(:product_publication, product: product, channel: secondary_channel, published_at: 1.day.from_now)
      expect(publication.published?).to be false
    end

    it 'is false when unpublished_at is in the past' do
      publication = build(
        :product_publication,
        product: product, channel: secondary_channel,
        published_at: 2.days.ago, unpublished_at: 1.day.ago
      )
      expect(publication.published?).to be false
    end
  end

  describe 'associations on Product' do
    it 'reaches channels through product_publications' do
      product.product_publications.create!(channel: secondary_channel)
      expect(product.reload.channels).to include(secondary_channel)
    end
  end
end
