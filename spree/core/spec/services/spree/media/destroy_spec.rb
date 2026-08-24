require 'spec_helper'

describe Spree::Media::Destroy do
  let(:product) { create(:product) }
  let(:media) { create(:image, viewable: product) }

  it 'destroys the row' do
    described_class.call(media: media)

    expect(Spree::Media.exists?(media.id)).to be(false)
  end

  it 'destroys every placement sharing the file' do
    copy = media.duplicate_for(create(:product))
    copy.save!

    described_class.call(media: media)

    expect(Spree::Media.exists?(copy.id)).to be(false)
  end

  it 'detaches a category slot holding the file' do
    category = create(:category)
    category.image.attach(media.attachment.blob)
    category.save!

    perform_enqueued_jobs { described_class.call(media: media) }

    expect(category.reload.image).not_to be_attached
  end

  it 'removes the file from storage once nothing references it' do
    blob = media.attachment.blob

    perform_enqueued_jobs { described_class.call(media: media) }

    expect(ActiveStorage::Blob.exists?(blob.id)).to be(false)
  end

  # A blob another tenant happens to share is theirs to keep — the detach
  # stays inside the file's own store and the foreign key preserves storage.
  it 'leaves another store alone' do
    other_store = create(:store)
    foreign = media.duplicate_for(create(:product, store: other_store))
    foreign.save!
    blob = media.attachment.blob

    perform_enqueued_jobs { described_class.call(media: media) }

    expect(Spree::Media.exists?(foreign.id)).to be(true)
    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
  end

  # purge_later hands the file to a worker that can run before the transaction
  # ends, so enqueueing inside it would destroy the file of a delete that then
  # rolled back.
  it 'does not detach anything when the deletion fails' do
    category = create(:category)
    category.image.attach(media.attachment.blob)
    category.save!
    allow(media).to receive(:destroy!).and_raise(ActiveRecord::Rollback)

    perform_enqueued_jobs do
      described_class.call(media: media) rescue nil
    end

    expect(category.reload.image).to be_attached
  end

  it 'leaves unrelated files alone' do
    unrelated = create(:image, viewable: create(:product))

    described_class.call(media: media)

    expect(Spree::Media.exists?(unrelated.id)).to be(true)
  end
end
