require 'spec_helper'

# The gate every digital file passes through. The marketplace's rules for a
# seller's file are exercised end to end in the Seller API controller spec;
# this covers the workflow's own contract: where a file lands, what a handler
# sees, and that the operator's writes are not subject to the seller rules.
RSpec.describe 'Spree::DigitalAssets write workflows' do
  let(:store) { @default_store }
  let(:product) { create(:product, store: store) }

  # Hooks registered by one example would otherwise fire in the next.
  after { Spree.hooks.clear! }

  def private_blob(filename = 'manual.pdf')
    ActiveStorage::Blob.create_and_upload!(
      io: File.open(Spree::Core::Engine.root.join('spec', 'fixtures', 'thinking-cat.jpg')),
      filename: filename,
      content_type: 'application/pdf',
      service_name: Spree.private_storage_service_name
    )
  end

  describe Spree::DigitalAssets::Create do
    it 'attaches the upload to the default variant' do
      result = described_class.call(product: product, attributes: { signed_id: private_blob.signed_id, authorized_clicks: 3 })

      expect(result).to be_success
      expect(result.value.variant).to eq(product.default_variant)
      expect(result.value.filename).to eq('manual.pdf')
      expect(result.value.authorized_clicks).to eq(3)
    end

    it "resolves the variant through the product's own variants" do
      variant = create(:variant, product: product)
      other = create(:variant, product: create(:product, store: store))

      result = described_class.call(product: product, attributes: { signed_id: private_blob.signed_id, variant_id: variant.prefixed_id })
      expect(result.value.variant).to eq(variant)

      expect do
        described_class.call(product: product, attributes: { signed_id: private_blob.signed_id, variant_id: other.prefixed_id })
      end.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'refuses an upload it cannot find' do
      result = described_class.call(product: product, attributes: { signed_id: 'expired' })

      expect(result).to be_failure
      expect(result.error.to_s).to match(/could not be found/)
    end

    # The bytes are in storage by the time the hook fires, so a scanner can
    # read them here and refuse before anything is attached.
    it 'lets a validate handler read the upload and reject it' do
      Spree.hooks.register('digital_assets.create.validate') do |workflow|
        workflow.reject!('the scanner refused this file') if workflow.blob.filename.to_s.end_with?('.pdf')
      end

      result = described_class.call(product: product, attributes: { signed_id: private_blob.signed_id })

      expect(result).to be_failure
      expect(result.error.to_s).to eq('the scanner refused this file')
      expect(Spree::DigitalAsset.count).to eq(0)
    end

    it 'dispatches after_create with the persisted asset' do
      seen = nil
      Spree.hooks.register('digital_assets.create.after_create') { |workflow| seen = workflow.digital_asset }

      result = described_class.call(product: product, attributes: { signed_id: private_blob.signed_id })

      expect(seen).to eq(result.value)
      expect(seen).to be_persisted
    end

    # The settings restrict what a seller may attach; the operator writing on
    # a seller's product is who those settings protect.
    it "does not hold the operator's own write to the seller rules" do
      stub_store_preferences(seller_digital_assets_enabled: false, seller_digital_asset_content_types: [])
      listing = create(:product, store: store, seller: create(:seller, :approved, store: store), status: 'active')

      result = described_class.call(product: listing, attributes: { signed_id: private_blob.signed_id })

      expect(result).to be_success
      expect(listing.reload).to be_active
    end
  end

  describe Spree::DigitalAssets::Update do
    let(:digital_asset) { create(:digital_asset, variant: product.default_variant, authorized_days: 7) }

    it 'shows a validate handler the pending edit and the replacement file' do
      seen = nil
      Spree.hooks.register('digital_assets.update.validate') do |workflow|
        seen = [workflow.digital_asset.changes.keys, workflow.blob&.filename.to_s]
      end

      result = described_class.call(digital_asset: digital_asset, attributes: { signed_id: private_blob.signed_id, authorized_days: nil })

      expect(result).to be_success
      expect(seen).to eq([%w[authorized_days], 'manual.pdf'])
      expect(digital_asset.reload.filename).to eq('manual.pdf')
    end

    it 'leaves the file alone when the payload carries none' do
      result = described_class.call(digital_asset: digital_asset, attributes: { authorized_clicks: 2 })

      expect(result).to be_success
      expect(digital_asset.reload).to have_attributes(authorized_clicks: 2, filename: 'thinking-cat.jpg')
    end
  end
end
