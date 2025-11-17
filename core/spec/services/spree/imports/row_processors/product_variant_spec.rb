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
    # Manually map fields since there's no CSV file attached
    import.mappings.find_by(schema_field: 'shipping_category')&.update(file_column: 'shipping_category')
    import.mappings.find_by(schema_field: 'tax_category')&.update(file_column: 'tax_category')
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

    context 'when updating an existing master variant' do
      let!(:existing_product) { create(:product, slug: 'denim-shirt', name: 'Old Name', stores: [store]) }

      before do
        stock_item = existing_product.master.stock_items.find_or_initialize_by(stock_location: store.default_stock_location)
        stock_item.count_on_hand = 50
        stock_item.backorderable = false
        stock_item.save!
      end

      it 'updates inventory_count and inventory_backorderable' do
        stock_item = existing_product.master.stock_items.find_by(stock_location: store.default_stock_location)
        expect(stock_item.count_on_hand).to eq 50
        expect(stock_item.backorderable).to eq false

        subject.process!

        stock_item.reload
        expect(stock_item.count_on_hand).to eq 100
        expect(stock_item.backorderable).to eq true
        expect(existing_product.reload.name).to eq 'Denim Shirt'
      end
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

    context 'when importing a variant row for existing variant' do
      let(:color_option_type) { Spree::OptionType.find_by(name: 'color') || create(:option_type, name: 'color', presentation: 'Color') }
      let(:size_option_type) { Spree::OptionType.find_by(name: 'size') || create(:option_type, name: 'size', presentation: 'Size') }
      let(:blue_option_value) { create(:option_value, name: 'Blue', presentation: 'Blue', option_type: color_option_type) }
      let(:xs_option_value) { create(:option_value, name: 'XS', presentation: 'XS', option_type: size_option_type) }
      let!(:variant) { create(:variant, product: product, sku: 'DENIM-SHIRT-XS-BLUE', price: 50.99, option_values: [blue_option_value, xs_option_value]) }

      it 'updates the variant' do
        expect { subject.process! }.to change { variant.reload.price }.from(50.99).to(62.99)
        expect(variant.option_values.map(&:presentation).sort).to contain_exactly('Blue', 'XS')
      end

      context 'when updating inventory values' do
        before do
          stock_item = variant.stock_items.find_or_initialize_by(stock_location: store.default_stock_location)
          stock_item.count_on_hand = 50
          stock_item.backorderable = false
          stock_item.save!
        end

        it 'updates inventory_count and inventory_backorderable' do
          stock_item = variant.stock_items.find_by(stock_location: store.default_stock_location)
          expect(stock_item.count_on_hand).to eq 50
          expect(stock_item.backorderable).to eq false

          subject.process!

          stock_item.reload
          expect(stock_item.count_on_hand).to eq 100
          expect(stock_item.backorderable).to eq true
        end
      end
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
      let!(:clothing_taxon) { create(:taxon, name: 'clothing', taxonomy: categories_taxonomy, parent: men_taxon) }
      let!(:shirts_category_taxon) { create(:taxon, name: 'Shirts', taxonomy: categories_taxonomy, parent: clothing_taxon) }

      let(:brands_taxonomy) { store.taxonomies.find_by(name: 'Brands') }
      let!(:awesome_brand_taxon) { create(:taxon, name: 'Awesome brand', taxonomy: brands_taxonomy, parent: brands_taxonomy.root) }

      let(:collections_taxonomy) { store.taxonomies.find_by(name: 'Collections') }
      let!(:summer_taxon) { create(:taxon, name: 'Summer', taxonomy: collections_taxonomy, parent: collections_taxonomy.root) }
      let!(:shirts_collection_taxon) { create(:taxon, name: 'Shirts', taxonomy: collections_taxonomy, parent: summer_taxon) }

      let(:row_data) do
        csv_row_hash(
          'slug' => 'denim-shirt',
          'category1' => 'categories -> Men -> Clothing -> Shirts',
          'category2' => 'brands -> awesome brand',
          'category3' => 'Collections -> Summer -> Shirts'
        )
      end

      it 'assigns the existing taxons to the product' do
        expect { subject.process! }.to change { Spree::Taxon.count }.by(0)

        expect(product.reload.taxons.map(&:pretty_name)).to contain_exactly(
          'Categories -> Men -> clothing -> Shirts',
          'Brands -> Awesome brand',
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

  context 'when importing a variant row with options but product does not exist' do
    let(:row_data) do
      csv_row_hash(
        'slug' => 'non-existent-shirt',
        'sku' => 'NON-EXISTENT-SHIRT-BLUE-XS',
        'price' => '62.99',
        'currency' => 'USD',
        'option1_name' => 'Color',
        'option1_value' => 'Blue',
        'option2_name' => 'Size',
        'option2_value' => 'XS'
      )
    end

    it 'raises ActiveRecord::RecordNotFound' do
      expect { subject.process! }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  context 'when importing a variant row with options but slug is missing' do
    let(:row_data) do
      csv_row_hash(
        'slug' => '',
        'sku' => 'MISSING-SLUG-BLUE-XS',
        'price' => '62.99',
        'currency' => 'USD',
        'option1_name' => 'Color',
        'option1_value' => 'Blue',
        'option2_name' => 'Size',
        'option2_value' => 'XS'
      )
    end

    it 'raises ActiveRecord::RecordNotFound with descriptive message' do
      expect { subject.process! }.to raise_error(ActiveRecord::RecordNotFound, 'Product slug is required for variant rows')
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

  context 'with metafields' do
    let!(:brand_metafield_definition) do
      create(:metafield_definition,
             namespace: 'custom',
             key: 'brand',
             name: 'Brand',
             resource_type: 'Spree::Product',
             metafield_type: 'Spree::Metafields::ShortText')
    end

    let!(:material_metafield_definition) do
      create(:metafield_definition,
             namespace: 'custom',
             key: 'material',
             name: 'Material',
             resource_type: 'Spree::Product',
             metafield_type: 'Spree::Metafields::ShortText')
    end

    let(:row_data) do
      base_data = csv_row_hash(
        'slug' => 'denim-shirt',
        'name' => 'Denim Shirt',
        'status' => 'active',
        'price' => '62.99',
        'currency' => 'USD'
      )
      # Add metafield keys directly to the hash
      base_data.merge(
        'metafield.custom.brand' => 'Awesome Brand',
        'metafield.custom.material' => 'Cotton'
      )
    end

    # Override the top-level before to create mappings after metafield definitions exist
    before do
      import.create_mappings
    end

    it 'creates mappings for metafields automatically' do
      expect(import.mappings.where(schema_field: 'metafield.custom.brand').exists?).to be true
      expect(import.mappings.where(schema_field: 'metafield.custom.material').exists?).to be true
    end

    it 'auto-assigns file_column for metafield mappings when CSV headers match' do
      # Verify CSV headers include metafield keys
      expect(import.csv_headers).to include('metafield.custom.brand', 'metafield.custom.material')

      brand_mapping = import.mappings.find_by(schema_field: 'metafield.custom.brand')
      material_mapping = import.mappings.find_by(schema_field: 'metafield.custom.material')

      expect(brand_mapping.file_column).to eq('metafield.custom.brand')
      expect(material_mapping.file_column).to eq('metafield.custom.material')
      expect(brand_mapping.mapped?).to be true
      expect(material_mapping.mapped?).to be true
    end

    it 'sets metafields on the product' do
      product = variant.product

      expect(product).to be_persisted
      expect(product.has_metafield?('custom.brand')).to be true
      expect(product.has_metafield?('custom.material')).to be true
      expect(product.get_metafield('custom.brand').value).to eq 'Awesome Brand'
      expect(product.get_metafield('custom.material').value).to eq 'Cotton'
    end

    context 'when updating an existing product with metafields' do
      let!(:existing_product) do
        p = create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store])
        p.set_metafield('custom.brand', 'Old Brand')
        p.set_metafield('custom.material', 'Old Material')
        p
      end

      it 'updates existing metafields' do
        product = variant.product

        expect(product.id).to eq existing_product.id
        expect(product.get_metafield('custom.brand').value).to eq 'Awesome Brand'
        expect(product.get_metafield('custom.material').value).to eq 'Cotton'
      end
    end

    context 'when metafield value is blank' do
      let(:row_data) do
        base_data = csv_row_hash(
          'slug' => 'denim-shirt',
          'name' => 'Denim Shirt',
          'status' => 'active',
          'price' => '62.99',
          'currency' => 'USD'
        )
        base_data.merge(
          'metafield.custom.brand' => 'Awesome Brand',
          'metafield.custom.material' => ''
        )
      end

      it 'skips blank metafield values' do
        product = variant.product

        expect(product.has_metafield?('custom.brand')).to be true
        expect(product.get_metafield('custom.brand').value).to eq 'Awesome Brand'
        expect(product.has_metafield?('custom.material')).to be false
      end
    end

    context 'when updating existing product metafields with blank values' do
      let!(:existing_product) do
        p = create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store])
        p.set_metafield('custom.brand', 'Old Brand')
        p.set_metafield('custom.material', 'Old Material')
        p
      end

      let(:row_data) do
        base_data = csv_row_hash(
          'slug' => 'denim-shirt',
          'name' => 'Denim Shirt',
          'status' => 'active',
          'price' => '62.99',
          'currency' => 'USD'
        )
        base_data.merge(
          'metafield.custom.brand' => 'New Brand',
          'metafield.custom.material' => ''
        )
      end

      it 'removes existing metafield when empty value is uploaded' do
        expect(existing_product.metafields.count).to eq 2

        product = variant.product

        expect(product.id).to eq existing_product.id
        expect(product.has_metafield?('custom.brand')).to be true
        expect(product.get_metafield('custom.brand').value).to eq 'New Brand'
        expect(product.has_metafield?('custom.material')).to be false
        expect(product.metafields.count).to eq 1
      end

      context 'when all metafields have blank values' do
        let(:row_data) do
          base_data = csv_row_hash(
            'slug' => 'denim-shirt',
            'name' => 'Denim Shirt',
            'status' => 'active',
            'price' => '62.99',
            'currency' => 'USD'
          )
          base_data.merge(
            'metafield.custom.brand' => '',
            'metafield.custom.material' => ''
          )
        end

        it 'removes all existing metafields' do
          expect(existing_product.metafields.count).to eq 2

          product = variant.product

          expect(product.id).to eq existing_product.id
          expect(product.has_metafield?('custom.brand')).to be false
          expect(product.has_metafield?('custom.material')).to be false
          expect(product.metafields.count).to eq 0
        end
      end
    end

    context 'when processing a non-master variant row' do
      let!(:existing_product) do
        p = create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store])
        p.set_metafield('custom.brand', 'Awesome Brand')
        p.set_metafield('custom.material', 'Cotton')
        p
      end

      let(:row_data) do
        csv_row_hash(
          'slug' => 'denim-shirt',
          'sku' => 'DENIM-SHIRT-BLUE-XS',
          'price' => '62.99',
          'currency' => 'USD',
          'option1_name' => 'Color',
          'option1_value' => 'Blue',
          'option2_name' => 'Size',
          'option2_value' => 'XS',
          'metafield.custom.brand' => '',
          'metafield.custom.material' => ''
        )
      end

      it 'does not clear out existing metafield values' do
        expect(existing_product.metafields.count).to eq 2

        product = variant.product

        expect(product.id).to eq existing_product.id
        expect(product.has_metafield?('custom.brand')).to be true
        expect(product.get_metafield('custom.brand').value).to eq 'Awesome Brand'
        expect(product.has_metafield?('custom.material')).to be true
        expect(product.get_metafield('custom.material').value).to eq 'Cotton'
        expect(product.metafields.count).to eq 2
      end
    end
  end

  context 'when importing with shipping_category' do
    context 'when shipping_category exists' do
      let!(:digital_category) { create(:shipping_category, name: 'Digital') }

      let(:row_data) do
        csv_row_hash(
          'slug' => 'digital-product',
          'name' => 'Digital Product',
          'status' => 'active',
          'price' => '29.99',
          'currency' => 'USD',
          'shipping_category' => 'Digital'
        )
      end

      it 'assigns the shipping category to the product' do
        product = variant.product
        expect(product.shipping_category).to eq digital_category
      end
    end

    context 'when shipping_category does not exist' do
      let(:row_data) do
        csv_row_hash(
          'slug' => 'digital-product',
          'name' => 'Digital Product',
          'status' => 'active',
          'price' => '29.99',
          'currency' => 'USD',
          'shipping_category' => 'NonExistent'
        )
      end

      it 'assigns the default shipping category' do
        product = variant.product
        expect(product.shipping_category).to be_present
        expect(product.shipping_category.name).to eq 'Default'
      end
    end

    context 'when updating product with different shipping_category' do
      let!(:standard_category) { create(:shipping_category, name: 'Standard') }
      let!(:digital_category) { create(:shipping_category, name: 'Digital') }
      let!(:existing_product) do
        create(:product, slug: 'product-to-update', name: 'Product', stores: [store], shipping_category: standard_category)
      end

      let(:row_data) do
        csv_row_hash(
          'slug' => 'product-to-update',
          'name' => 'Product',
          'status' => 'active',
          'price' => '29.99',
          'currency' => 'USD',
          'shipping_category' => 'Digital'
        )
      end

      it 'updates the shipping category' do
        product = variant.product

        expect(product.id).to eq existing_product.id
        expect(product.shipping_category).to eq digital_category
      end
    end

    context 'when shipping_category is not provided' do
      let(:row_data) do
        csv_row_hash(
          'slug' => 'product-no-category',
          'name' => 'Product',
          'status' => 'active',
          'price' => '29.99',
          'currency' => 'USD'
        )
      end

      it 'assigns the default shipping category' do
        product = variant.product

        expect(product.shipping_category).to be_present
        expect(product.shipping_category.name).to eq 'Default'
      end
    end
  end

  context 'when importing with tax_category' do
    context 'when tax_category exists' do
      let!(:clothing_tax) { create(:tax_category, name: 'Clothing') }

      let(:row_data) do
        csv_row_hash(
          'slug' => 'test-product',
          'name' => 'Test Product',
          'status' => 'active',
          'price' => '29.99',
          'currency' => 'USD',
          'tax_category' => 'Clothing'
        )
      end

      it 'assigns the tax category to the variant' do
        expect(variant.tax_category).to eq clothing_tax
      end
    end

    context 'when tax_category does not exist' do
      let(:row_data) do
        csv_row_hash(
          'slug' => 'test-product',
          'name' => 'Test Product',
          'status' => 'active',
          'price' => '29.99',
          'currency' => 'USD',
          'tax_category' => 'NonExistent'
        )
      end

      it 'does not assign a tax category' do
        expect(variant.tax_category).to be_nil
      end
    end

    context 'when updating variant with different tax_category' do
      let!(:standard_tax) { create(:tax_category, name: 'Standard') }
      let!(:clothing_tax) { create(:tax_category, name: 'Clothing') }
      let!(:existing_product) do
        p = create(:product, slug: 'product-to-update', name: 'Product', stores: [store])
        p.master.update(tax_category: standard_tax)
        p
      end

      let(:row_data) do
        csv_row_hash(
          'slug' => 'product-to-update',
          'name' => 'Product',
          'status' => 'active',
          'price' => '29.99',
          'currency' => 'USD',
          'tax_category' => 'Clothing'
        )
      end

      it 'updates the tax category' do
        product = variant.product

        expect(product.id).to eq existing_product.id
        expect(variant.tax_category).to eq clothing_tax
      end
    end

    context 'when tax_category is not provided' do
      let(:row_data) do
        csv_row_hash(
          'slug' => 'product-no-tax',
          'name' => 'Product',
          'status' => 'active',
          'price' => '29.99',
          'currency' => 'USD'
        )
      end

      it 'does not assign a tax category' do
        expect(variant.tax_category).to be_nil
      end
    end

    context 'when importing a non-master variant with tax_category' do
      let!(:clothing_tax) { create(:tax_category, name: 'Clothing') }
      let!(:product) do
        p = create(:product, slug: 'denim-shirt', name: 'Denim Shirt', stores: [store])
        color = create(:option_type, name: 'color', presentation: 'Color')
        p.option_types << color
        p
      end

      let(:row_data) do
        csv_row_hash(
          'slug' => 'denim-shirt',
          'sku' => 'DENIM-SHIRT-BLUE',
          'price' => '62.99',
          'currency' => 'USD',
          'tax_category' => 'Clothing',
          'option1_name' => 'Color',
          'option1_value' => 'Blue'
        )
      end

      it 'assigns tax category to the non-master variant' do
        expect(variant.is_master?).to be false
        expect(variant.tax_category).to eq clothing_tax
      end
    end
  end
end
