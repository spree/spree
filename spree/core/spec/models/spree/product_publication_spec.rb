require 'spec_helper'

RSpec.describe Spree::ProductPublication, type: :model do
  let(:store) { @default_store }
  let(:channel) { store.default_channel }
  let(:product) { create(:product) }

  # +StoreScopedResource+ auto-attaches every product to +Store.default+,
  # so tests needing a pristine (product, store) slot use this pair.
  let(:other_store) { create(:store, default: false, code: 'other') }
  let(:other_channel) { other_store.default_channel }

  describe 'validations' do
    it 'is valid with product, store, and channel' do
      publication = build(:product_publication, product: product, store: other_store, channel: other_channel)
      expect(publication).to be_valid
    end

    it 'enforces uniqueness per (product, store)' do
      duplicate = build(:product_publication, product: product, store: store, channel: channel)
      expect(duplicate).not_to be_valid
    end

    it 'rejects unpublished_at before published_at' do
      publication = build(
        :product_publication,
        product: product, store: other_store, channel: other_channel,
        published_at: 1.day.from_now, unpublished_at: 1.hour.from_now
      )
      expect(publication).not_to be_valid
      expect(publication.errors[:unpublished_at]).to be_present
    end
  end

  describe 'channel auto-assignment' do
    it 'derives channel from store.default_channel when only store is given' do
      publication = Spree::ProductPublication.new(product: product, store: other_store)
      publication.valid?
      expect(publication.channel).to eq(other_store.default_channel)
    end
  end

  describe '.published' do
    it 'includes publications with null dates' do
      publication = create(:product_publication, product: product, store: other_store, channel: other_channel)
      expect(described_class.published).to include(publication)
    end

    it 'excludes publications with future published_at' do
      publication = create(
        :product_publication,
        product: product, store: other_store, channel: other_channel,
        published_at: 1.day.from_now
      )
      expect(described_class.published).not_to include(publication)
    end

    it 'excludes publications with past unpublished_at' do
      publication = create(
        :product_publication,
        product: product, store: other_store, channel: other_channel,
        published_at: 2.days.ago, unpublished_at: 1.day.ago
      )
      expect(described_class.published).not_to include(publication)
    end
  end

  describe '#published?' do
    it 'is true when dates are nil' do
      expect(build(:product_publication, product: product, store: other_store, channel: other_channel).published?).to be true
    end

    it 'is false when published_at is in the future' do
      publication = build(:product_publication, product: product, store: other_store, channel: other_channel, published_at: 1.day.from_now)
      expect(publication.published?).to be false
    end

    it 'is false when unpublished_at is in the past' do
      publication = build(
        :product_publication,
        product: product, store: other_store, channel: other_channel,
        published_at: 2.days.ago, unpublished_at: 1.day.ago
      )
      expect(publication.published?).to be false
    end
  end

  describe 'associations on Product' do
    let(:product_with_store) { create(:product) }

    it 'reaches stores through product_publications' do
      expect(product_with_store.stores).to include(store)
    end

    it 'reaches channels through product_publications' do
      expect(product_with_store.channels).to include(channel)
    end
  end
end
