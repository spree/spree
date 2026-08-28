require 'spec_helper'

RSpec.describe Spree::DigitalAssetProvider::File do
  let(:digital_asset) { create(:digital_asset) }
  let(:digital_link) { create(:digital_link, digital_asset: digital_asset) }

  subject(:provider) { described_class.new(digital_asset) }

  # The Disk service needs a host to sign a URL; a real request supplies it via
  # ActiveStorage::SetCurrent. Outside a request the spec sets it directly.
  around do |example|
    ActiveStorage::Current.url_options = { host: 'http://test.host' }
    example.run
  ensure
    ActiveStorage::Current.url_options = nil
  end

  it 'is registered as a selectable provider' do
    expect(Spree.digital_asset_providers).to include(described_class)
  end

  it 'requires an attachment' do
    expect(described_class.requires_attachment?).to be(true)
  end

  describe '#deliver' do
    it 'returns a redirect to a signed storage URL' do
      delivery = provider.deliver(digital_link, expires_in: 5.minutes)

      expect(delivery).to be_redirect
      expect(delivery.redirect_url).to be_present
    end

    # File is a refactor of DigitalAsset#download_url; the signed URLs are not
    # byte-equal (the expiry timestamp is stamped at call time), so decode the
    # signed disk token from each and compare the blob key + disposition.
    def decoded_disk_payload(url)
      token = url[%r{/disk/([^/]+)/}, 1]
      ActiveStorage.verifier.verified(token, purpose: :blob_key)
    end

    it 'reproduces the asset download URL (no behaviour change)' do
      via_provider = decoded_disk_payload(provider.deliver(digital_link, expires_in: 5.minutes).redirect_url)
      via_model = decoded_disk_payload(digital_asset.download_url(expires_in: 5.minutes))

      expect(via_provider['key']).to eq(via_model['key'])
      expect(via_provider['disposition']).to eq(via_model['disposition'])
      expect(via_provider['disposition']).to include('attachment')
    end

    it 'returns nothing when no file is attached' do
      digital_asset.attachment.purge

      expect(provider.deliver(digital_link, expires_in: 5.minutes)).to be_nil
    end
  end
end
