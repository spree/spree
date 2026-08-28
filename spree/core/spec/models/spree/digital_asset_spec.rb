require 'spec_helper'

describe Spree::DigitalAsset, type: :model do
  include ActionDispatch::TestProcess::FixtureFile

  let(:file_upload) { fixture_file_upload(file_fixture('icon_256x256.png'), 'image/png') }
  let(:variant) { create(:variant) }

  it_behaves_like 'lifecycle events'

  it 'validates presence of variant' do
    expect(described_class.new(attachment: file_upload)).not_to be_valid
  end

  it 'validates presence of attachment' do
    expect(described_class.new(variant: variant)).not_to be_valid
  end

  it 'validates presence of attachment and variant' do
    expect(described_class.new(variant: variant, attachment: file_upload)).to be_valid
  end

  describe 'providers' do
    # A stand-in provider that resolves its deliverable elsewhere, so it needs
    # no uploaded file. Registered for the duration of the examples.
    let(:stub_provider) do
      Class.new(Spree::DigitalAssetProvider::Base) do
        def self.requires_attachment? = false
        def deliver(_link, expires_in:) = Spree::DigitalDelivery.new(inline_value: 'STUB')
      end
    end

    before do
      stub_const('Spree::DigitalAssetProvider::Stub', stub_provider)
      Spree.digital_asset_providers << stub_provider
    end

    after { Spree.digital_asset_providers.delete(stub_provider) }

    it 'resolves a blank provider_type to the File default' do
      expect(described_class.new.provider_class).to eq(Spree::DigitalAssetProvider::File)
    end

    it 'resolves a set provider_type to that class' do
      asset = described_class.new(provider_type: 'Spree::DigitalAssetProvider::Stub')
      expect(asset.provider_class).to eq(stub_provider)
    end

    it 'requires no attachment for a provider that declares so' do
      asset = described_class.new(variant: variant, provider_type: 'Spree::DigitalAssetProvider::Stub')
      expect(asset).to be_valid
    end

    it 'still requires an attachment for a File asset' do
      expect(described_class.new(variant: variant)).not_to be_valid
    end

    it 'rejects an unregistered provider_type' do
      asset = described_class.new(variant: variant, provider_type: 'Spree::DigitalAssetProvider::Gone')
      expect(asset).not_to be_valid
      expect(asset.errors[:provider_type]).to be_present
    end

    # A provider_type naming a real class that is not a provider must fail
    # validation cleanly rather than raising when the attachment validation
    # asks it whether it requires a file.
    it 'rejects a provider_type that names a non-provider class without raising' do
      asset = described_class.new(variant: variant, provider_type: 'Spree::Product')

      expect { asset.valid? }.not_to raise_error
      expect(asset).not_to be_valid
      expect(asset.errors[:provider_type]).to be_present
    end

    it 'stores provider settings under one key in metadata' do
      asset = described_class.new
      asset.provider_settings = { 'pool_name' => 'winter' }

      expect(asset.provider_settings).to eq('pool_name' => 'winter')
      expect(asset.metadata['provider']).to eq('pool_name' => 'winter')
    end

    it 'returns an empty hash when no provider settings are set' do
      expect(described_class.new.provider_settings).to eq({})
    end
  end

  # The legacy names are the one-release webhook bridge; dropping them silently
  # would break every subscriber written before the rename.
  describe 'legacy digital.* events', events: true do
    let(:digital_asset) { build(:digital_asset) }

    it 'emits the legacy name alongside the canonical one on create' do
      expect(digital_asset).to receive(:publish_event).with('digital.created')
      expect(digital_asset).to receive(:publish_event).with('digital_asset.created')

      digital_asset.save!
    end

    it 'emits the legacy name alongside the canonical one on update' do
      digital_asset.save!
      expect(digital_asset).to receive(:publish_event).with('digital.updated')
      expect(digital_asset).to receive(:publish_event).with('digital_asset.updated')

      Timecop.travel(1.minute.from_now) { digital_asset.update_attribute(:updated_at, Time.current) }
    end

    it 'does not emit either name on a bare touch' do
      digital_asset.save!
      expect(digital_asset).not_to receive(:publish_event).with('digital.updated')
      expect(digital_asset).not_to receive(:publish_event).with('digital_asset.updated')
      allow(digital_asset).to receive(:publish_event).with(anything)

      digital_asset.touch
    end

    it 'emits the legacy name alongside the canonical one on destroy' do
      digital_asset.save!
      expect(digital_asset).to receive(:publish_event).with('digital.deleted', kind_of(Hash))
      expect(digital_asset).to receive(:publish_event).with('digital_asset.deleted', kind_of(Hash))

      digital_asset.destroy!
    end
  end

  it 'rejects non-positive limit overrides' do
    expect(described_class.new(variant: variant, attachment: file_upload, authorized_clicks: 0)).not_to be_valid
    expect(described_class.new(variant: variant, attachment: file_upload, authorized_days: -1)).not_to be_valid
  end

  describe 'effective limits' do
    let(:store) { @default_store }
    let(:digital_asset) { create(:digital_asset) }

    before do
      store.update!(preferred_digital_asset_authorized_clicks: 5, preferred_digital_asset_authorized_days: 7)
    end

    it 'falls back to the store settings when the asset leaves them blank' do
      expect(digital_asset.effective_authorized_clicks).to eq(5)
      expect(digital_asset.effective_authorized_days).to eq(7)
    end

    it 'prefers the asset overrides when present' do
      digital_asset.update!(authorized_clicks: 99, authorized_days: 365)

      expect(digital_asset.effective_authorized_clicks).to eq(99)
      expect(digital_asset.effective_authorized_days).to eq(365)
    end

    it 'overrides each limit independently' do
      digital_asset.update!(authorized_clicks: 99)

      expect(digital_asset.effective_authorized_clicks).to eq(99)
      expect(digital_asset.effective_authorized_days).to eq(7)
    end
  end

  # Replacing a file must never revoke access for people who already bought it.
  describe 'replacing the attachment' do
    let(:digital_asset) { create(:digital_asset) }
    let!(:digital_link) { create(:digital_link, digital_asset: digital_asset) }

    it 'keeps existing links pointing at the new file' do
      digital_asset.attachment.attach(io: File.new(file_fixture('icon_256x256.png')), filename: 'replacement.png')

      expect(digital_link.reload.digital_asset.filename.to_s).to eq('replacement.png')
      expect(digital_link).to be_authorizable
    end
  end
end
