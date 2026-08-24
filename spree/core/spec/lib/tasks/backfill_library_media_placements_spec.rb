require 'spec_helper'
require 'rake'

describe 'spree:upgrade:backfill_library_media_placements' do
  subject { Rake::Task[task_name] }

  let(:task_name) { 'spree:upgrade:backfill_library_media_placements' }

  before(:all) do
    Rake::Task.define_task(:environment)
    load Spree::Core::Engine.root.join('lib', 'tasks', 'backfill_library_media_placements.rake')
  end

  before { subject.reenable }

  def attach_image(record, slot = :image)
    record.public_send(slot).attach(
      io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
      filename: 'thinking-cat.jpg'
    )
  end

  # Simulates a pre-6.0 record: the attachment exists, the placement does not.
  def strip_placements(record)
    Spree::Media.unscoped.where(viewable: record).delete_all
    record.media.reset
  end

  it 'places a category image that predates the library' do
    category = create(:category)
    attach_image(category)
    category.save!
    strip_placements(category)

    subject.invoke

    expect(category.media.reload.sole.attachment.blob).to eq(category.image.blob)
  end

  it 'places a collection image that predates the library' do
    collection = create(:collection)
    attach_image(collection)
    collection.save!
    strip_placements(collection)

    subject.invoke

    expect(collection.media.reload.count).to eq(1)
  end

  it 'can be run twice' do
    category = create(:category)
    attach_image(category)
    category.save!

    subject.invoke
    subject.reenable
    subject.invoke

    expect(category.media.reload.count).to eq(1)
  end

  it 'leaves records without images alone' do
    category = create(:category)

    subject.invoke

    expect(category.media.reload).to be_empty
  end
end
