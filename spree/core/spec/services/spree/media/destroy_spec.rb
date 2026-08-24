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

  # A Spree::Store has no store_id of its own, so a blank one must not read as
  # "mine" — deleting one store's file was stripping another store's logo.
  it 'leaves another store logo on the same file alone' do
    foreign_store = create(:store)
    foreign_store.logo.attach(media.attachment.blob)
    foreign_store.save!

    perform_enqueued_jobs { described_class.call(media: media) }

    expect(foreign_store.reload.logo).to be_attached
  end

  # A poster is a still another row may use as its own picture, so deleting a
  # video must not take that independent image with it.
  it 'leaves an image reusing the video poster alone' do
    video = create(:video_media, viewable: product)
    video.poster.attach(
      io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
      filename: 'still.jpg'
    )
    video.save!

    reuse = Spree::Media.new(store: product.store, viewable: product, media_type: 'image')
    reuse.attachment.attach(video.poster.blob)
    reuse.save!

    described_class.call(media: video)

    expect(Spree::Media.exists?(reuse.id)).to be(true)
  end

  it 'leaves unrelated files alone' do
    unrelated = create(:image, viewable: create(:product))

    described_class.call(media: media)

    expect(Spree::Media.exists?(unrelated.id)).to be(true)
  end
end
