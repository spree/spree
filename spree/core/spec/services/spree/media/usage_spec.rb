require 'spec_helper'

describe Spree::Media::Usage do
  subject(:usage) { described_class.call(media: media).value }

  let(:product) { create(:product, name: 'Original product') }
  let(:media) { create(:image, viewable: product) }

  # The library shows a file, not a placement, so the product it sits on is
  # part of the answer. Omitting it read as "not used anywhere" for a file that
  # is plainly on a product — exactly wrong before a delete.
  it 'reports the product the file sits on' do
    reference = usage.find { |candidate| candidate.kind == 'media' }

    expect(reference).to be_present
    expect(reference.name).to eq('Original product')
    expect(reference.owner_type).to eq('Spree::Product')
  end

  it 'is empty for a file placed nowhere' do
    unplaced = create(:image, viewable: nil)

    expect(described_class.call(media: unplaced).value).to be_empty
  end

  it 'reports every product a copy was placed on' do
    other_product = create(:product, name: 'Reused on this one')
    media.duplicate_for(other_product).save!

    names = usage.select { |candidate| candidate.kind == 'media' }.map(&:name)

    expect(names).to contain_exactly('Original product', 'Reused on this one')
  end

  # A file picked for a store logo shares the blob without going through
  # Spree::Media at all, so usage has to be a question about the blob.
  it 'reports a plain attachment sharing the blob' do
    # A dedicated store, not the suite-wide default — attaching a logo to the
    # shared record would leak into every later spec.
    store = create(:store)
    store.logo.attach(media.attachment.blob)
    store.save!

    reference = usage.find { |candidate| candidate.kind == 'attachment' }

    expect(reference).to be_present
    expect(reference.field).to eq('logo')
  end

  # A category holds a file twice — its image slot and the slot's library
  # placement. The merchant should see the category once, as the placement,
  # which is what the dashboard can link to.
  it 'reports a category using the file once' do
    category = create(:category, name: 'Summer')
    category.image.attach(media.attachment.blob)
    category.save!

    references = usage.select { |candidate| candidate.name == 'Summer' }

    expect(references.size).to eq(1)
    expect(references.first.kind).to eq('media')
    expect(references.first.owner_type).to eq('Spree::Category')
  end

  it 'reports a description embedding the file' do
    create(
      :product,
      name: 'Has it in the copy',
      description: %(<p>See <img src="/rails/blobs/#{media.attachment.blob.key}/x.webp"></p>)
    )

    reference = usage.find { |candidate| candidate.kind == 'rich_text' }

    expect(reference).to be_present
    expect(reference.name).to eq('Has it in the copy')
    expect(reference.field).to eq('description')
  end

  it 'is empty for a row with no file' do
    external_video = create(:external_video_media, viewable: product)

    expect(described_class.call(media: external_video).value).to be_empty
  end

  # The video file and its poster are two blobs on one row, so the row's own
  # placement is reachable twice. A merchant should see the product once.
  it 'reports a video with a poster once' do
    video = create(:video_media, viewable: product)
    video.poster.attach(
      io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
      filename: 'thinking-cat.jpg'
    )
    video.save!

    references = described_class.call(media: video).value

    expect(references.count { |reference| reference.kind == 'media' }).to eq(1)
  end

  # A file is one store's, so its uses are that store's rows. Reporting another
  # tenant's records would name them to a merchant who cannot see them anywhere
  # else in the dashboard.
  describe 'across stores' do
    let(:other_store) { create(:store) }

    it 'ignores a placement in another store sharing the file' do
      foreign_product = create(:product, store: other_store, name: 'Another tenant')
      copy = media.duplicate_for(foreign_product)
      copy.save!

      expect(usage.map(&:name)).not_to include('Another tenant')
    end

    it 'ignores an attachment in another store sharing the blob' do
      foreign_category = create(:category, store: other_store, name: 'Their category')
      foreign_category.image.attach(media.attachment.blob)
      foreign_category.save!

      expect(usage.map(&:name)).not_to include('Their category')
    end

    it 'ignores a description in another store embedding the file' do
      create(
        :product,
        store: other_store,
        name: 'Their copy',
        description: %(<p><img src="/rails/blobs/#{media.attachment.blob.key}/x.webp"></p>)
      )

      expect(usage.map(&:name)).not_to include('Their copy')
    end
  end
end
