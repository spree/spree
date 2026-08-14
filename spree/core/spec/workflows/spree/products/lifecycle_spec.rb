require 'spec_helper'

module Spree
  RSpec.describe 'product workflows' do
    let(:store) { @default_store }

    after { Spree.hooks.clear! }

    describe Products::Create do
      it 'creates the product' do
        result = described_class.call(store: store, attributes: { name: 'Chair' })

        expect(result).to be_success
        expect(result.value).to be_persisted
        expect(result.value.name).to eq('Chair')
        expect(result.value.store).to eq(store)
      end

      it 'lets a validate handler reject the product before it is written' do
        Spree.hooks.register('products.create.validate') do |flow|
          flow.errors.add(:name, :reserved_word, message: 'may not contain "sample"')
          flow.reject! if flow.product.name.to_s.include?('sample')
        end

        result = described_class.call(store: store, attributes: { name: 'a sample chair' })

        expect(result).to be_failure
        expect(result.error.to_s).to include('may not contain')
        expect(Product.find_by(name: 'a sample chair')).to be_nil
      end

      it 'fires after_create with the saved product' do
        seen = nil
        Spree.hooks.register('products.create.after_create') { |flow| seen = flow.product }

        described_class.call(store: store, attributes: { name: 'Desk' })

        expect(seen).to be_persisted
        expect(seen.name).to eq('Desk')
      end

      it 'returns a failure when the product is invalid' do
        result = described_class.call(store: store, attributes: { name: '' })

        expect(result).to be_failure
        expect(result.error.to_s).to include("Name can't be blank")
      end

      # Nested data is written by the model's after_create callbacks, so a
      # rejection before the insert leaves no half-built product behind.
      it 'writes no nested data when a handler rejects' do
        Spree.hooks.register('products.create.validate') { |flow| flow.reject!('not allowed') }

        result = nil
        expect do
          result = described_class.call(
            store: store,
            attributes: { name: 'Rejected', variants: [{ sku: 'REJ-1' }] }
          )
        end.not_to change(Variant, :count)

        expect(result).to be_failure
        expect(Product.find_by(name: 'Rejected')).to be_nil
      end

      # The setters live on the model, so a workflow create gets them too.
      it 'applies nested variants through the model setters' do
        result = described_class.call(
          store: store,
          attributes: { name: 'With variants', variants: [{ sku: 'WV-1' }] }
        )

        expect(result).to be_success
        expect(result.value.variants.map(&:sku)).to include('WV-1')
      end

      # The CSV importer assigns attributes across several steps and hands over
      # the record rather than a hash.
      it 'accepts an already-built product' do
        product = store.products.new(name: 'Prebuilt')

        result = described_class.call(store: store, record: product)

        expect(result).to be_success
        expect(product.reload).to be_persisted
      end
    end

    describe Products::Update do
      let(:product) { create(:product, store: store, name: 'Original') }

      it 'applies the attributes' do
        result = described_class.call(product: product, attributes: { name: 'Renamed' })

        expect(result).to be_success
        expect(product.reload.name).to eq('Renamed')
      end

      # Reading `changes` in validate is what makes "the price may not drop
      # below cost" expressible without a model validation.
      it 'exposes the pending edit to a validate handler' do
        pending_change = nil
        Spree.hooks.register('products.update.validate') { |flow| pending_change = flow.product.changes['name'] }

        described_class.call(product: product, attributes: { name: 'Renamed' })

        expect(pending_change).to eq(%w[Original Renamed])
      end

      it 'leaves the record untouched when a handler rejects' do
        Spree.hooks.register('products.update.validate') { |flow| flow.reject!('locked for editing') }

        result = described_class.call(product: product, attributes: { name: 'Renamed' })

        expect(result).to be_failure
        expect(product.reload.name).to eq('Original')
      end
    end

    describe Products::Destroy do
      let!(:product) { create(:product, store: store) }

      it 'soft-deletes the product' do
        result = described_class.call(product: product)

        expect(result).to be_success
        expect(product.reload.deleted_at).to be_present
      end

      it 'lets a handler refuse the deletion' do
        Spree.hooks.register('products.destroy.validate') { |flow| flow.reject!('still under contract') }

        result = described_class.call(product: product)

        expect(result).to be_failure
        expect(result.error.to_s).to eq('still under contract')
        expect(product.reload.deleted_at).to be_nil
      end

      it 'fires after_destroy for host cleanup' do
        fired = false
        Spree.hooks.register('products.destroy.after_destroy') { fired = true }

        described_class.call(product: product)

        expect(fired).to be(true)
      end
    end
  end
end
