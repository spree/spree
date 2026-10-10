require 'spec_helper'

RSpec.describe Spree::Uploads::AssignStores do
  let(:store) { @default_store }
  let(:other_store) { create(:store) }

  def storeless_blob
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new('bytes'), filename: 'file.png', content_type: 'image/png').tap do |blob|
      blob.update_column(:store_id, nil)
    end
  end

  def attach_without_check(record, slot, blob)
    ActiveStorage::Attachment.insert_all!([{ name: slot, record_type: record.class.base_class.name, record_id: record.id,
                                             blob_id: blob.id, created_at: Time.current }])
  end

  it 'gives attached files the store of their owner' do
    category_blob = storeless_blob
    attach_without_check(create(:category, store: other_store), 'image', category_blob)
    seller_blob = storeless_blob
    attach_without_check(create(:seller, store: other_store), 'logo', seller_blob)
    unattached = storeless_blob

    result = described_class.call

    expect(result.value[:assigned]).to eq(2)
    expect(category_blob.reload.store_id).to eq(other_store.id)
    expect(seller_blob.reload.store_id).to eq(other_store.id)
    expect(unattached.reload.store_id).to be_nil
  end

  it 'asks owners without a store column record by record' do
    blob = storeless_blob
    attach_without_check(other_store, 'logo', blob)

    described_class.call

    expect(blob.reload.store_id).to eq(other_store.id)
  end

  it 'reports a file attached in two stores' do
    blob = storeless_blob
    attach_without_check(create(:category, store: store), 'image', blob)
    attach_without_check(create(:category, store: other_store), 'image', blob)

    expect(described_class.call.value[:conflicts]).to eq([blob.id])
  end

  it 'leaves files that already have a store alone' do
    blob = storeless_blob
    blob.update_column(:store_id, store.id)
    attach_without_check(create(:category, store: other_store), 'image', blob)

    expect { described_class.call }.not_to(change { blob.reload.store_id })
  end
end
