require 'spec_helper'

RSpec.describe Spree::Imports::RowsPreprocessors::Products, type: :service do
  subject { described_class.new(import).preprocess_rows! }

  let(:store) { @default_store }
  let(:import) { create(:product_import, owner: store) }

  before do
    import.create_mappings
  end

  let!(:row1) do
    create(:import_row, import: import, row_number: 1, data: {
      'slug' => 'product-1', 'sku' => 'SKU1', 'name' => 'Product 1', 'price' => '10',
      'category1' => 'Men -> Clothing -> Shirts',
      'category2' => 'Brands -> Nike'
    }.to_json)
  end

  let!(:row2) do
    create(:import_row, import: import, row_number: 2, data: {
      'slug' => 'product-2', 'sku' => 'SKU2', 'name' => 'Product 2', 'price' => '20',
      'category1' => 'Men -> Clothing -> Pants',
      'category2' => 'Brands -> Nike'
    }.to_json)
  end

  it 'creates all referenced taxonomies and taxons' do
    expect { subject }
      .to change { Spree::Taxonomy.count }.by(2)
      .and change { Spree::Taxon.count }.by(6) # 2 roots + Clothing + Shirts + Pants + Nike

    men_taxonomy = store.taxonomies.find_by(name: 'Men')
    expect(men_taxonomy).to be_present
    expect(men_taxonomy.taxons.find_by(name: 'Clothing')).to be_present
    expect(men_taxonomy.taxons.find_by(name: 'Shirts')).to be_present
    expect(men_taxonomy.taxons.find_by(name: 'Pants')).to be_present

    brands_taxonomy = store.taxonomies.find_by(name: 'Brands')
    expect(brands_taxonomy).to be_present
    expect(brands_taxonomy.taxons.find_by(name: 'Nike')).to be_present
  end

  it 'is idempotent' do
    subject

    expect { subject }
      .not_to change { Spree::Taxon.count }
  end

  context 'when no category mappings exist' do
    before do
      import.mappings.where(schema_field: %w[category1 category2 category3]).update_all(file_column: nil)
    end

    it 'does not create taxonomies' do
      expect { subject }.not_to change { Spree::Taxonomy.count }
    end

    it 'does not create taxons' do
      expect { subject }.not_to change { Spree::Taxon.count }
    end
  end

  context 'when rows have no category values' do
    let!(:row1) do
      create(:import_row, import: import, row_number: 1, data: {
        'slug' => 'product-1', 'sku' => 'SKU1', 'name' => 'Product 1', 'price' => '10'
      }.to_json)
    end

    let!(:row2) do
      create(:import_row, import: import, row_number: 2, data: {
        'slug' => 'product-2', 'sku' => 'SKU2', 'name' => 'Product 2', 'price' => '20'
      }.to_json)
    end

    it 'does not create taxonomies' do
      expect { subject }.not_to change { Spree::Taxonomy.count }
    end

    it 'does not create taxons' do
      expect { subject }.not_to change { Spree::Taxon.count }
    end
  end

  context 'when taxons format is invalid' do
    let!(:row1) do
      create(:import_row, import: import, row_number: 1, data: {
        'slug' => 'product-1', 'sku' => 'SKU1', 'name' => 'Product 1', 'price' => '10',
        'category1' => 'Unisex -> -> Shirts',
        'category2' => ' -> ',
        'category3' => '   '
      }.to_json)
    end

    let!(:row2) do
      create(:import_row, import: import, row_number: 2, data: {
        'slug' => 'product-2', 'sku' => 'SKU2', 'name' => 'Product 2', 'price' => '20',
        'category1' => 'Unisex -> -> Shirts',
        'category2' => ' -> ',
        'category3' => '   '
      }.to_json)
    end

    it 'strips breadcrumb formatting and creates given taxonomies and taxons' do
      expect { subject }
        .to change { Spree::Taxonomy.count }.by(1)
        .and change { Spree::Taxon.count }.by(2) # 1 root + Shirts

      unisex_taxonomy = store.taxonomies.find_by(name: 'Unisex')
      expect(unisex_taxonomy).to be_present
      expect(unisex_taxonomy.taxons.find_by(name: 'Shirts')).to be_present
    end
  end
end
