require 'spec_helper'

RSpec.describe Spree::Imports::RowProcessors::ProductTranslation, type: :service do
  subject { described_class.new(row) }

  let(:store) { Spree::Store.default }
  let(:import) { create(:product_translation_import, owner: store) }
  let(:row) { create(:import_row, import: import, data: row_data.to_json) }
  let(:csv_row_headers) { Spree::ImportSchemas::ProductTranslations.new.headers }

  before do
    import.create_mappings
  end

  def csv_row_hash(attrs = {})
    csv_row_headers.index_with { |header| attrs[header] }
  end

  context 'when importing a German translation' do
    let!(:product) { create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store]) }

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'locale' => 'de',
        'name' => 'Jeanshemd',
        'description' => 'Ein klassisches Jeanshemd.',
        'meta_title' => 'Jeanshemd | Demo',
        'meta_description' => 'Klassisches Jeanshemd.'
      )
    end

    it 'sets the German translation on the product' do
      subject.process!

      Mobility.with_locale(:de) do
        product.reload
        expect(product.name).to eq 'Jeanshemd'
        expect(product.description).to eq 'Ein klassisches Jeanshemd.'
        expect(product.meta_title).to eq 'Jeanshemd | Demo'
        expect(product.meta_description).to eq 'Klassisches Jeanshemd.'
      end
    end

    it 'does not change the English name' do
      subject.process!
      expect(product.reload.name).to eq 'Denim Shirt'
    end

    it 'returns the product' do
      expect(subject.process!).to eq product
    end
  end

  context 'when updating an existing translation' do
    let!(:product) { create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store]) }

    before do
      Mobility.with_locale(:de) { product.update!(name: 'Altes Jeanshemd') }
    end

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'locale' => 'de',
        'name' => 'Neues Jeanshemd'
      )
    end

    it 'updates the translation' do
      subject.process!

      Mobility.with_locale(:de) do
        expect(product.reload.name).to eq 'Neues Jeanshemd'
      end
    end
  end

  context 'when all translatable fields are blank' do
    let!(:product) { create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store]) }

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'locale' => 'fr',
        'name' => '',
        'description' => ''
      )
    end

    it 'skips the row without error' do
      expect(subject.process!).to eq product
    end
  end

  context 'when slug does not match any product' do
    let(:row_data) do
      csv_row_hash(
        'slug' => 'nonexistent-product',
        'locale' => 'de',
        'name' => 'Nichtexistent'
      )
    end

    it 'raises RecordNotFound' do
      expect { subject.process! }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when locale is missing' do
    let!(:product) { create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store]) }

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'locale' => '',
        'name' => 'Jeanshemd'
      )
    end

    it 'raises ArgumentError' do
      expect { subject.process! }.to raise_error(ArgumentError, 'Locale is required')
    end
  end

  context 'with partial fields' do
    let!(:product) { create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store]) }

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'locale' => 'fr',
        'name' => 'Chemise en Jean'
      )
    end

    it 'only sets the provided field' do
      subject.process!

      Mobility.with_locale(:fr) do
        product.reload
        expect(product.name).to eq 'Chemise en Jean'
        expect(product.meta_title).to be_nil
      end
    end
  end
end
