require 'spec_helper'

RSpec.describe Spree::Exports::Products, type: :model do
  let(:store) { @default_store }
  let(:export) { described_class.new(store: store) }

  describe '#scope' do
    let!(:archived_product) { create(:product, status: 'archived') }
    let!(:test_product) { create(:product, name: 'test') }

    context 'when search_params is nil' do
      it 'excludes archived products' do
        expect(export.scope).to include(test_product)
        expect(export.scope).not_to include(archived_product)
      end
    end

    context 'when search_params is present' do
      let(:export) { described_class.new(store: store, search_params: { name: 'test' }) }

      it 'includes all products' do
        expect(export.scope).to include(test_product)
        expect(export.scope).to include(archived_product)
      end
    end
  end

  describe '#generate' do
    let(:seller) { create(:seller, :approved, store: store) }
    let(:product) { create(:product, store: store, seller: seller) }
    let(:seller_location) { create(:stock_location, store: store, seller: seller, name: 'Seller Shed') }

    before do
      product.default_variant.update!(sku: 'SHED-MUG', track_inventory: true)
      product.default_variant.set_stock(12, false, store.default_stock_location)
      product.default_variant.set_stock(7, false, seller_location)
    end

    it "writes only a seller's own stock on the seller's export" do
      export = described_class.new(store: store, seller: seller)
      export.save!
      export.generate

      rows = CSV.parse(export.attachment.download, headers: true)
      expect(rows.map { |row| row.values_at('sku', 'inventory_count', 'stock_location') }).to eq [['SHED-MUG', '7', nil]]
    end

    it "writes the product's gallery images so a re-import keeps them" do
      media = create(:media, viewable: product)
      export = described_class.new(store: store)
      export.save!
      export.generate

      row = CSV.parse(export.attachment.download, headers: true).find { |csv_row| csv_row['sku'] == 'SHED-MUG' }
      expect(row['image1_src']).to end_with(media.filename.to_s)
    end
  end

  # The job runs in the locale of whatever asked for the export — a request in
  # the store's own language, or the application's default.
  describe "#generate for a store whose default locale is not the application's" do
    let(:dutch_store) { create(:store) }

    before do
      dutch_store.default_market.update!(default_locale: 'nl', supported_locales: 'nl,en')
      create(:product, store: dutch_store.reload, name: 'Fiets', description: 'Een stadsfiets')
    end

    %i[nl en].each do |job_locale|
      it "writes the product names and descriptions when the job runs in #{job_locale}" do
        export = described_class.new(store: dutch_store)
        export.save!
        I18n.with_locale(job_locale) { export.generate }

        rows = CSV.parse(export.attachment.download, headers: true)
        expect(rows.map { |row| row.values_at('name', 'description') }).to eq [['Fiets', 'Een stadsfiets']]
      end
    end

    # The admin filtered a list shown in English; the export holds the rows
    # that list showed, written in the store's own language.
    it 'selects rows by a translated filter in the locale it was asked for in' do
      dutch_store.products.first.translations.create!(locale: 'en', name: 'Bicycle')
      export = described_class.new(store: dutch_store, search_params: { name_cont: 'Bicycle' })
      export.save!
      I18n.with_locale(:en) { export.generate }

      rows = CSV.parse(export.attachment.download, headers: true)
      expect(rows.pluck('name')).to eq ['Fiets']
    end

    it "does not leave the exported store's content locale behind" do
      export = described_class.new(store: dutch_store)
      export.save!
      I18n.with_locale(:nl) { export.generate }

      expect(Spree::Current.attributes[:content_locale]).to be_nil
    end
  end

  describe '#csv_headers' do
    let(:base_headers) do
      [
        'product_id',
        'sku',
        'name',
        'slug',
        'status',
        'seller_name',
        'description',
        'meta_title',
        'meta_description',
        'meta_keywords',
        'tags',
        'labels',
        'price',
        'compare_at_price',
        'currency',
        'width',
        'height',
        'depth',
        'dimensions_unit',
        'weight',
        'weight_unit',
        'available_on',
        'discontinue_on',
        'track_inventory',
        'inventory_count',
        'inventory_backorderable',
        'stock_location',
        'tax_category',
        'product_type',
        'image1_src',
        'image2_src',
        'image3_src',
        'option1_name',
        'option1_value',
        'option2_name',
        'option2_value',
        'option3_name',
        'option3_value',
        'category1',
        'category2',
        'category3'
      ]
    end

    context 'when no custom_fields' do
      it 'returns product variant headers without properties' do
        expect(export.csv_headers).to eq(base_headers)
      end
    end

    context 'when custom_fields exist' do
      let!(:custom_field_definition) { create(:custom_field_definition, resource_type: 'Spree::Product', namespace: 'custom', key: 'field1') }

      it 'includes custom_field headers' do
        expect(export.csv_headers).to eq(base_headers + ['custom_field.custom.field1'])
      end
    end
  end
end
