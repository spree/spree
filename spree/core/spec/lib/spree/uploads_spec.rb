require 'spec_helper'

RSpec.describe Spree::Uploads do
  let(:store) { @default_store }
  let(:other_store) { create(:store) }
  let(:category) { create(:category, store: store) }

  def create_blob(store_id: nil)
    ActiveStorage::Blob.create_and_upload!(io: StringIO.new('bytes'), filename: 'file.png', content_type: 'image/png').tap do |blob|
      blob.update_column(:store_id, store_id)
    end
  end

  describe 'store assignment on creation' do
    it 'takes the store a request or job declared' do
      Spree::Current.store = other_store

      expect(create_blob_without_override.store_id).to eq(other_store.id)
    end

    it 'leaves the store empty rather than guessing the default' do
      expect(create_blob_without_override.store_id).to be_nil
    end

    def create_blob_without_override
      ActiveStorage::Blob.create_and_upload!(io: StringIO.new('bytes'), filename: 'file.png', content_type: 'image/png')
    end
  end

  describe 'store check on attachment' do
    it 'gives a file created for the attachment its owner store' do
      seller = create(:seller, store: store)
      seller.logo.attach(io: File.open(Spree::Core::Engine.root.join('spec/fixtures/thinking-cat.jpg')),
                         filename: 'logo.jpg', content_type: 'image/jpeg')

      expect(seller.reload.logo.blob.store_id).to eq(store.id)
    end

    it 'attaches a file of the same store quietly' do
      expect(Rails.logger).not_to receive(:warn)

      category.update!(image_signed_id: create_blob(store_id: store.id).signed_id)
    end

    it 'logs, without refusing, a file of another store' do
      # Category images also become media library placements, which report too.
      expect(Rails.logger).to receive(:warn).with(/belongs to store #{other_store.id}.*Spree 6.1 refuses/).at_least(:once)

      category.update!(image_signed_id: create_blob(store_id: other_store.id).signed_id)

      expect(category.reload.image).to be_attached
    end

    it 'logs an existing file without a store' do
      expect(Rails.logger).to receive(:warn).with(/has no store/).at_least(:once)

      category.update!(image_signed_id: create_blob.signed_id)
    end

    it 'does not check records that belong to no store' do
      expect(Rails.logger).not_to receive(:warn)

      create(:admin_user).update!(avatar_signed_id: create_blob(store_id: other_store.id).signed_id)
    end
  end

  describe '.signed_id_for' do
    it 'mints a reference that stops resolving after a day' do
      signed_id = described_class.signed_id_for(create_blob)

      Timecop.travel(25.hours.from_now) do
        expect(ActiveStorage::Blob.find_signed(signed_id)).to be_nil
      end
    end
  end
end
