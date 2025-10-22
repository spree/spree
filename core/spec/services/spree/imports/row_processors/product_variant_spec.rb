require 'spec_helper'

RSpec.describe Spree::Imports::RowProcessors::ProductVariant, type: :service do
  subject { described_class.new(row) }

  let(:store) { Spree::Store.default }
  let(:import) { create(:product_import, owner: store) }
  let(:row) { create(:import_row, import: import, data: row_data.to_json) }
  let(:csv_row_headers) { Spree::ImportSchemas::Products.new.headers }
  let(:variant) { subject.process! }

  before do
    import.create_mappings
  end

  # Matches how our production import will pass attributes
  def csv_row_hash(attrs = {})
    csv_row_headers.index_with { |header| attrs[header] }
  end

  context 'when importing a master variant product row' do
    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'name' => 'Denim Shirt',
        'status' => 'draft',
        'description' => 'Adipisci sapiente velit nihil ullam. Placeat cumque ipsa cupiditate velit magni sapiente mollitia dolorum. Veritatis esse illo eos perferendis. Perspiciatis vel iusto odio eveniet quam officia quidem. Fugiat a ipsum tempore optio accusantium autem in fugit.',
        'price' => '62.99',
        'currency' => 'USD',
        'weight' => '0.0',
        'inventory_count' => '100',
        'inventory_backorderable' => 'true',
        'tags' => 'ECO, Gold'
      )
    end

    it 'creates a product and sets correct attributes' do
      product = variant.product

      expect(product).to be_persisted
      expect(product.slug).to eq 'denim-shirt'
      expect(product.name).to eq 'Denim Shirt'
      expect(product.status).to eq 'draft'
      expect(product.description).to eq row_data['description']
      expect(product.stores).to include(store)
      expect(product.tag_list).to contain_exactly('ECO', 'Gold')
      expect(product.master).to eq variant
      expect(variant.sku).to be_blank
      expect(variant.price_in('USD').amount.to_f).to eq 62.99
      expect(variant.weight.to_f).to eq 0.0
      expect(variant.stock_items.first.count_on_hand).to eq 100
      expect(variant.stock_items.first.backorderable).to eq true
    end
  end

  context 'when importing a variant row with options' do
    let!(:product) do
      # Pre-create the product and associate to the store
      p = create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store])
      # Add Color and Size option types
      color = create(:option_type, name: 'color', presentation: 'Color')
      size = create(:option_type, name: 'size', presentation: 'Size')
      p.option_types << color
      p.option_types << size
      p
    end

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'sku' => 'DENIM-SHIRT-XS-BLUE',
        'price' => '62.99',
        'currency' => 'USD',
        'weight' => '0.0',
        'inventory_count' => '100',
        'inventory_backorderable' => 'true',
        'option1_name' => 'Color',
        'option1_value' => 'Blue',
        'option2_name' => 'Size',
        'option2_value' => 'XS',
      )
    end

    it 'assigns to existing product and creates/re-uses option values' do
      expect(variant).to be_persisted
      expect(variant.sku).to eq 'DENIM-SHIRT-XS-BLUE'
      expect(variant.price_in('USD').amount.to_f).to eq 62.99

      expect(variant.option_values.map(&:presentation).sort).to contain_exactly('Blue', 'XS')

      # Option values should exist for those names
      color_option_type = Spree::OptionType.search_by_name('Color').first
      size_option_type = Spree::OptionType.search_by_name('Size').first
      expect(color_option_type).to be_present
      expect(size_option_type).to be_present
      expect(color_option_type.option_values.find_by(presentation: 'Blue')).to be_present
      expect(size_option_type.option_values.find_by(presentation: 'XS')).to be_present
    end
  end

  context 'when importing a variant row with a new option type/value' do
    let!(:product) do
      create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store])
    end

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'sku' => 'DENIM-SHIRT-NEW-GREEN',
        'option1_name' => 'Finish',
        'option1_value' => 'Green',
        'price' => '62.99',
        'currency' => 'USD',
      )
    end

    it 'creates a new option type and value as needed' do
      expect do
        subject.process!
      end.to change { Spree::OptionType.where(presentation: 'Finish').count }.by(1)
        .and change { Spree::OptionValue.where(presentation: 'Green').count }.by(1)

      variant = subject.process!

      expect(variant.option_values.map(&:presentation)).to include('Green')
    end
  end

  context 'with images' do
    let!(:product) do
      create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store])
    end

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'image1_src' => 'https://example.com/image1.jpg',
        'image2_src' => 'https://example.com/image2.jpg',
        'image3_src' => 'https://example.com/image3.jpg'
      )
    end

    it 'saves the images' do
      expect { subject.process! }.to have_enqueued_job(Spree::Images::SaveFromUrlJob).exactly(3).times.on_queue(Spree.queues.images)
        .and have_enqueued_job(Spree::Images::SaveFromUrlJob).with(variant.id, 'Spree::Variant', row_data['image1_src'])
        .and have_enqueued_job(Spree::Images::SaveFromUrlJob).with(variant.id, 'Spree::Variant', row_data['image2_src'])
        .and have_enqueued_job(Spree::Images::SaveFromUrlJob).with(variant.id, 'Spree::Variant', row_data['image3_src'])
    end
  end

  context 'with taxons' do
    let!(:product) { create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store], taxons: taxons) }
    let(:taxons) { [] }

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'category1' => 'Categories -> Men -> Clothing -> Shirts',
        'category2' => 'Brands -> Awesome Brand',
        'category3' => 'Collections -> Summer -> Shirts'
      )
    end

    it 'assigns taxons to the product' do
      expect { subject.process! }.to change { Spree::Taxon.count }.by(6)

      expect(product.reload.taxons.map(&:pretty_name)).to contain_exactly(
        'Categories -> Men -> Clothing -> Shirts',
        'Brands -> Awesome Brand',
        'Collections -> Summer -> Shirts'
      )
    end

    context 'when the taxons already exist' do
      let(:categories_taxonomy) { store.taxonomies.find_by(name: 'Categories') }
      let!(:men_taxon) { create(:taxon, name: 'Men', taxonomy: categories_taxonomy, parent: categories_taxonomy.root) }
      let!(:clothing_taxon) { create(:taxon, name: 'Clothing', taxonomy: categories_taxonomy, parent: men_taxon) }
      let!(:shirts_category_taxon) { create(:taxon, name: 'Shirts', taxonomy: categories_taxonomy, parent: clothing_taxon) }

      let(:brands_taxonomy) { store.taxonomies.find_by(name: 'Brands') }
      let!(:awesome_brand_taxon) { create(:taxon, name: 'Awesome Brand', taxonomy: brands_taxonomy, parent: brands_taxonomy.root) }

      let(:collections_taxonomy) { store.taxonomies.find_by(name: 'Collections') }
      let!(:summer_taxon) { create(:taxon, name: 'Summer', taxonomy: collections_taxonomy, parent: collections_taxonomy.root) }
      let!(:shirts_collection_taxon) { create(:taxon, name: 'Shirts', taxonomy: collections_taxonomy, parent: summer_taxon) }

      it 'assigns the existing taxons to the product' do
        expect { subject.process! }.to change { Spree::Taxon.count }.by(0)

        expect(product.reload.taxons.map(&:pretty_name)).to contain_exactly(
          'Categories -> Men -> Clothing -> Shirts',
          'Brands -> Awesome Brand',
          'Collections -> Summer -> Shirts'
        )
      end
    end

    context 'when taxons are not provided' do
      let(:categories_taxonomy) { store.taxonomies.find_by(name: 'Categories') }
      let!(:men_taxon) { create(:taxon, name: 'Men', taxonomy: categories_taxonomy, parent: categories_taxonomy.root) }
      let!(:clothing_taxon) { create(:taxon, name: 'Clothing', taxonomy: categories_taxonomy, parent: men_taxon) }

      let(:taxons) { [clothing_taxon] }

      let(:row_data) do
        csv_row_hash(
          'slug' => 'denim-shirt',
          'category1' => '',
          'category2' => nil
        )
      end

      it 'assigns no taxons to the product' do
        expect { subject.process! }.to change { Spree::Taxon.count }.by(0)
        expect(product.reload.taxons).to be_empty
      end
    end

    context 'when taxons format is invalid' do
      let(:row_data) do
        csv_row_hash(
          'slug' => 'denim-shirt',
          'category1' => 'Categories -> Men -> -> Shirts',
          'category2' => ' -> ',
          'category3' => '   '
        )
      end

      it 'skips invalid taxons' do
        expect { subject.process! }.to change { Spree::Taxon.count }.by(2)

        expect(product.reload.taxons.map(&:pretty_name)).to contain_exactly(
          'Categories -> Men -> Shirts'
        )
      end
    end

    context 'when importing a variant row with no taxons' do
      let(:categories_taxonomy) { store.taxonomies.find_by(name: 'Categories') }
      let!(:men_taxon) { create(:taxon, name: 'Men', taxonomy: categories_taxonomy, parent: categories_taxonomy.root) }
      let!(:clothing_taxon) { create(:taxon, name: 'Clothing', taxonomy: categories_taxonomy, parent: men_taxon) }

      let(:taxons) { [clothing_taxon] }

      let(:row_data) do
        csv_row_hash(
          'slug' => 'denim-shirt',
          'sku' => 'DENIM-SHIRT-XS-BLUE',
          'price' => '62.99',
          'currency' => 'USD',
          'weight' => '0.0',
          'inventory_count' => '100',
          'inventory_backorderable' => 'true',
          'option1_name' => 'Color',
          'option1_value' => 'Blue',
          'option2_name' => 'Size',
          'option2_value' => 'XS',
        )
      end

      it 'keeps the product taxons' do
        expect(variant).to be_persisted
        expect(variant.sku).to eq 'DENIM-SHIRT-XS-BLUE'
        expect(variant.product).to eq(product)

        expect(product.reload.taxons.map(&:pretty_name)).to contain_exactly(
          'Categories -> Men -> Clothing'
        )
      end
    end
  end

  context 'when importing a variant with all option columns empty' do
    let!(:product) do
      create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store])
    end

    let(:row_data) do
      csv_row_hash(
        'slug' => 'denim-shirt',
        'sku' => 'DENIM-SHIRT-PLAIN',
        'price' => '62.99',
        'currency' => 'USD'
      )
    end

    it 'does not create a variant' do
      expect { subject.process! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  context 'when variant row refers to missing product slug' do
    let(:row_data) do
      csv_row_hash(
        'slug' => 'new-missing-shirt',
        'sku' => 'NEW-MISSING-SHIRT-SKU',
        'name' => 'Brand New Shirt',
        'status' => 'active',
        'price' => '99.99',
        'currency' => 'USD'
      )
    end

    it 'creates a new product and assigns the variant as its master if no option1_name given' do
      variant = subject.process!
      product = variant.product

      expect(product).to be_persisted
      expect(product.slug).to eq 'new-missing-shirt'
      expect(product.master).to eq variant
      expect(variant.sku).to eq 'NEW-MISSING-SHIRT-SKU'
    end
  end
end
