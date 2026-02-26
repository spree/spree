require 'spec_helper'

xdescribe Spree::Core::Search::Base do
  let(:product1) { create(:product, name: 'RoR Mug', price: 9.00) }
  let!(:product2) { create(:product, name: 'RoR Shirt', price: 11.00) }
  let(:taxon) { create(:taxon, name: 'Ruby on Rails') }
  before do
    product1.taxons << taxon
  end

  it 'returns all products by default' do
    params = { per_page: '' }
    searcher = described_class.new(params)
    expect(searcher.retrieve_products.count).to eq(2)
  end

  context 'when include_images is included in the initialization params' do
    subject { described_class.new(params).retrieve_products }

    let(:params) { { include_images: true, keyword: product1.name, taxon: taxon } }

    before do
      product1.master.images << create(:image, position: 2)
      product1.master.images << create(:image, position: 1)
      product1.reload
    end

    it 'returns images in correct order' do
      expect(subject.first).to eq product1
      expect(subject.first.images).to eq product1.master.images
    end
  end

  it 'switches to next page according to the page parameter' do
    @product3 = create(:product, name: 'RoR Pants', price: 14.00)

    params = { per_page: '2' }
    searcher = described_class.new(ActionController::Parameters.new(params))
    expect(searcher.retrieve_products.count).to eq(2)

    params[:page] = '2'
    searcher = described_class.new(ActionController::Parameters.new(params))
    expect(searcher.retrieve_products.count).to eq(1)
  end

  it 'uses ransack if scope not found' do
    params = { per_page: '', search: { 'name_not_cont' => 'Shirt' } }
    searcher = described_class.new(ActionController::Parameters.new(params))
    expect(searcher.retrieve_products.count).to eq(1)
  end

  it 'accepts a current user' do
    user = double
    searcher = described_class.new({})
    searcher.current_user = user
    expect(searcher.current_user).to eql(user)
  end

  it 'finds products in alternate currencies' do
    create(:price, currency: 'EUR', variant: product1.master)
    searcher = described_class.new({})
    searcher.current_currency = 'EUR'
    expect(searcher.retrieve_products).to eq([product1])
  end

  describe 'searching by a current store' do
    subject(:retrieved_products) { searcher.retrieve_products }

    let(:searcher) { described_class.new(params) }

    let(:eu_store) { create(:store, name: 'EU Store', default_currency: 'EUR') }
    let(:uk_store) { create(:store, name: 'UK Store', default_currency: 'GBP') }
    let(:spree_store) { create(:store, name: 'Spree Demo Site', default_currency: 'USD', default: true) }

    let!(:products_for_eu_store) do
      (1..3).map do |v|
        create(:product, name: "P-EU-#{v}", stores: [eu_store], currency: 'EUR')
      end
    end

    let!(:products_for_uk_store) do
      (1..2).map do |v|
        create(:product, name: "P-UK-#{v}", stores: [uk_store], currency: 'GBP')
      end
    end

    let!(:product_for_spree_store) { create(:product, name: 'P-Spree-1', stores: [spree_store]) }

    context 'current sture is given in params' do
      let(:params) { { current_store: current_store } }

      context 'when EU Store' do
        let(:current_store) { eu_store }

        it 'returns 3 products' do
          expect(retrieved_products.count).to eq(3)
        end

        it 'returns only products from EU store' do
          expect(retrieved_products).to contain_exactly(*products_for_eu_store)
        end
      end

      context 'when UK Store' do
        let(:current_store) { uk_store }

        it 'returns 2 products' do
          expect(retrieved_products.count).to eq(2)
        end

        it 'returns only products from UK store' do
          expect(retrieved_products).to contain_exactly(*products_for_uk_store)
        end
      end

      context 'when Spree Store' do
        let(:current_store) { spree_store }

        it 'returns 1 product' do
          expect(retrieved_products.count).to eq(1)
        end

        it 'returns only products from Spree store' do
          expect(retrieved_products).to contain_exactly(product_for_spree_store)
        end
      end
    end
  end

  it 'returns products with shirt in name when keyword set to shirt' do
    params = { keywords: 'shirt', include_images: true }
    searcher = described_class.new(ActionController::Parameters.new(params))
    expect(searcher.retrieve_products.first.name).to eq('RoR Shirt')
  end
end
