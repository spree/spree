require 'spec_helper'

RSpec.describe Spree::Uploads::PurgeUnattachedJob do
  def create_blob(created_at:)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new('bytes'), filename: 'file.png', content_type: 'image/png').tap do |blob|
      blob.update_column(:created_at, created_at)
    end
  end

  it 'deletes files never attached once they are past the retention period' do
    stale = create_blob(created_at: 3.days.ago)
    fresh = create_blob(created_at: 1.day.ago)
    attached = create_blob(created_at: 3.days.ago)
    ActiveStorage::Attachment.create!(name: 'image', record: create(:category), blob: attached)

    described_class.perform_now

    expect(ActiveStorage::Blob.where(id: [stale.id, fresh.id, attached.id])).to contain_exactly(fresh, attached)
  end

  it 'reads the retention period from configuration' do
    allow(Spree::Config).to receive(:unattached_upload_retention_days).and_return(7)
    blob = create_blob(created_at: 3.days.ago)

    described_class.perform_now

    expect(ActiveStorage::Blob.exists?(blob.id)).to be(true)
  end
end
