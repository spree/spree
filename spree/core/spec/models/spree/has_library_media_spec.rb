require 'spec_helper'

RSpec.shared_examples 'library media slots' do
  let(:record) { create(described_factory) }

  def fixture_upload(filename = 'thinking-cat.jpg')
    Rack::Test::UploadedFile.new(
      Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg',
      'image/jpeg',
      original_filename: filename
    )
  end

  it 'places an uploaded slot image in the library' do
    record.image.attach(fixture_upload)
    record.save!

    placement = record.media.sole
    expect(placement.attachment.blob).to eq(record.image.blob)
    expect(placement.store_id).to eq(record.store_id)
    expect(placement.alt).to eq('thinking-cat.jpg')
  end

  it 'places each slot with its own file' do
    record.image.attach(fixture_upload('wide.jpg'))
    record.square_image.attach(fixture_upload('square.jpg'))
    record.save!

    expect(record.media.count).to eq(2)
  end

  # The same file in both slots is one file — the library shows files.
  it 'places one row when both slots hold the same file' do
    record.image.attach(fixture_upload)
    record.save!
    record.square_image.attach(record.image.blob)
    record.save!

    expect(record.media.count).to eq(1)
  end

  it 'unplaces the old file when a slot is replaced' do
    record.image.attach(fixture_upload('first.jpg'))
    record.save!
    first_placement = record.media.sole

    record.image.attach(fixture_upload('second.jpg'))
    record.save!

    expect(record.media.reload.sole.alt).to eq('second.jpg')
    expect(first_placement.reload.viewable).to be_nil
    expect(first_placement.attachment).to be_attached
  end

  it 'unplaces the file when a slot is cleared' do
    record.image.attach(fixture_upload)
    record.save!
    placement = record.media.sole

    record.image = nil
    record.save!

    expect(placement.reload.viewable).to be_nil
    expect(placement.attachment).to be_attached
  end

  # A picked library file arrives as an existing blob; placing it must not
  # duplicate the file in storage.
  it 'shares the blob when a library file is picked into a slot' do
    library_file = create(:image, viewable: nil)

    expect {
      record.image.attach(library_file.attachment.blob)
      record.save!
    }.not_to change(ActiveStorage::Blob, :count)

    expect(record.media.sole.attachment.blob).to eq(library_file.attachment.blob)
  end

  it 'does not touch placements on a save that leaves the slots alone' do
    record.image.attach(fixture_upload)
    record.save!
    placement = record.media.sole

    expect { record.update!(name: 'Renamed') }.not_to change { placement.reload.updated_at }
  end

  it 'returns its files to the library when destroyed' do
    record.image.attach(fixture_upload)
    record.save!
    placement = record.media.sole

    record.destroy!

    expect(placement.reload.viewable_id).to be_nil
    expect(placement.attachment).to be_attached
  end
end

describe Spree::HasLibraryMedia do
  describe Spree::Category do
    let(:described_factory) { :category }

    include_examples 'library media slots'
  end

  describe Spree::Collection do
    let(:described_factory) { :collection }

    include_examples 'library media slots'
  end
end
