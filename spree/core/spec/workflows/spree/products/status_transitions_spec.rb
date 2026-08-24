require 'spec_helper'

# Variants and media are reconciled by the workflow, not by the model: the
# payload is the writer's whole intent, so it is a replacement rather than an
# assignment. These guard the POST /products response, which serializes the
# same in-memory product it just created.
RSpec.describe 'Spree::Products nested attributes' do
  let(:store) { Spree::Store.default }

  it 'creates the variants the payload carries' do
    result = Spree.product_create_workflow.call(
      store: store,
      attributes: {
        name: 'Deferred',
        variants: [{ sku: 'DEF-1', options: [{ name: 'Color', value: 'Red' }] }]
      }
    )

    expect(result).to be_success
    expect(result.value.variants.count).to eq(1)
    expect(result.value.variants.first.sku).to eq('DEF-1')
  end

  it 'reflects them in derived state without a reload' do
    result = Spree.product_create_workflow.call(
      store: store,
      attributes: {
        name: 'Fresh',
        variants: [{ sku: 'FV-1', prices: [{ amount: 10, currency: 'USD' }], options: [] }]
      }
    )
    product = result.value

    expect(product.variant_count).to eq(1)
    expect(product.default_variant.sku).to eq('FV-1')
    expect(product.price_in('USD').amount).to eq(10)
  end

  # The veto has to land before the insert, or a rejected create would leave
  # variants and images behind with no product to hang them on.
  it 'writes no nested data when a validate handler rejects' do
    Spree.hooks.clear!
    Spree.hooks.register('products.create.validate') { |workflow| workflow.reject!('nope') }

    expect {
      result = Spree.product_create_workflow.call(
        store: store,
        attributes: { name: 'Vetoed', variants: [{ sku: 'VETO-1', options: [] }] }
      )
      expect(result).not_to be_success
    }.not_to change(Spree::Variant, :count)
  ensure
    Spree.hooks.clear!
  end

  # These are public entry points: a host app or importer passing a plain
  # string-keyed hash must not have its nested payload fall through to the
  # ActiveRecord collection setter, which rejects hashes.
  it 'accepts a string-keyed payload' do
    result = Spree.product_create_workflow.call(
      store: store,
      attributes: { 'name' => 'StringKeys', 'variants' => [{ 'sku' => 'SK-1', 'options' => [] }] }
    )

    expect(result).to be_success
    expect(result.value.variants.first.sku).to eq('SK-1')
  end

  describe 'media given as a library file' do
    let(:product) { create(:product, store: store) }
    let(:library_file) { create(:image, viewable: create(:product, store: store)) }

    it 'places a copy sharing the source file' do
      expect {
        Spree.product_update_workflow.call(
          product: product,
          attributes: { media: [{ source_media_id: library_file.prefixed_id, alt: 'Reused' }] }
        )
      }.to change { product.media.count }.by(1)

      placed = product.media.reload.last
      expect(placed.attachment.blob).to eq(library_file.attachment.blob)
      expect(placed.alt).to eq('Reused')
    end

    it 'uploads nothing' do
      library_file # created before the block, so only the copy is counted

      expect {
        Spree.product_update_workflow.call(
          product: product,
          attributes: { media: [{ source_media_id: library_file.prefixed_id }] }
        )
      }.not_to change(ActiveStorage::Blob, :count)
    end

    # Both keys are permitted on the inline list, so a client can send both.
    # Whichever branch runs must not see the other's key as an attribute.
    it 'ignores a signed_id sent alongside the source' do
      result = Spree.product_update_workflow.call(
        product: product,
        attributes: { media: [{ source_media_id: library_file.prefixed_id, signed_id: 'abc' }] }
      )

      expect(result).to be_success
      expect(product.media.reload.last.attachment.blob).to eq(library_file.attachment.blob)
    end

    # The same tenancy rule the media endpoint enforces with a 404.
    it 'ignores a file from another store' do
      foreign = create(:image, viewable: create(:product, store: create(:store)))

      expect {
        Spree.product_update_workflow.call(
          product: product,
          attributes: { media: [{ source_media_id: foreign.prefixed_id }] }
        )
      }.not_to change { product.media.count }
    end
  end

  it 'enqueues a download for media given as an external url' do
    product = create(:product, store: store)

    expect {
      Spree.product_update_workflow.call(
        product: product,
        attributes: { media: [{ external_url: 'https://example.com/a.jpg', position: 1 }] }
      )
    }.to have_enqueued_job(Spree::Images::SaveFromUrlJob)
  end

  # The job loads the product by id, so a worker must not see it before the
  # transaction that created it has committed.
  it 'does not enqueue the download until the transaction commits' do
    enqueued_mid_transaction = nil

    ApplicationRecord.transaction do
      Spree.product_create_workflow.call(
        store: store,
        attributes: { name: 'Deferred Media', media: [{ external_url: 'https://example.com/b.jpg' }] }
      )
      enqueued_mid_transaction = enqueued_jobs.count { |job| job['job_class'] == 'Spree::Images::SaveFromUrlJob' }
    end

    expect(enqueued_mid_transaction).to eq(0)
    expect(enqueued_jobs.count { |job| job['job_class'] == 'Spree::Images::SaveFromUrlJob' }).to eq(1)
  end
end

RSpec.describe 'Spree::Products status workflows' do
  let(:store) { Spree::Store.default }

  describe Spree::Products::Activate do
    let(:product) { create(:product, status: 'draft', store: store) }

    it 'puts the product on sale' do
      expect { described_class.call(product: product) }.to change { product.reload.status }.from('draft').to('active')
    end

    it 'publishes product.activated', events: true do
      allow(product).to receive(:publish_event).with(anything)
      expect(product).to receive(:publish_event).with('product.activated')

      described_class.call(product: product)
    end

    context 'hooks' do
      before { Spree.hooks.clear! }
      after { Spree.hooks.clear! }

      it 'runs the after_activate hook' do
        seen = []
        Spree.hooks.register('products.activate.after_activate') { |workflow| seen << workflow.product }

        described_class.call(product: product)

        expect(seen).to eq([product])
      end

      it 'can be vetoed' do
        Spree.hooks.register('products.activate.validate') { |workflow| workflow.reject!('nope') }

        result = described_class.call(product: product)

        expect(result).not_to be_success
        expect(product.reload.status).to eq('draft')
      end
    end
  end

  describe Spree::Products::Archive do
    let(:product) { create(:product, status: 'active', store: store) }

    it 'takes the product off sale' do
      expect { described_class.call(product: product) }.to change { product.reload.status }.from('active').to('archived')
    end

    it 'publishes product.archived', events: true do
      allow(product).to receive(:publish_event).with(anything)
      expect(product).to receive(:publish_event).with('product.archived')

      described_class.call(product: product)
    end
  end

  describe Spree::Products::Draft do
    let(:product) { create(:product, status: 'active', store: store) }

    it 'returns the product to draft' do
      expect { described_class.call(product: product) }.to change { product.reload.status }.from('active').to('draft')
    end
  end
end
