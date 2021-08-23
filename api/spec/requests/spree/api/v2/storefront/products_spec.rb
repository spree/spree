require 'spec_helper'

describe 'API V2 Storefront Products Spec', type: :request do
  let!(:store)                     { Spree::Store.default }
  let!(:products)                  { create_list(:product, 5, stores: [store]) }
  let(:taxonomy)                   { create(:taxonomy, store: store) }
  let!(:taxon)                     { taxonomy.root }
  let(:product_with_taxon)         { create(:product, taxons: [taxon], stores: [store]) }
  let(:product_with_name)          { create(:product, name: 'Test Product', stores: [store]) }
  let(:product_with_price)         { create(:product, price: 13.44, stores: [store]) }
  let!(:option_type)               { create(:option_type) }
  let!(:option_value)              { create(:option_value, option_type: option_type) }
  let(:product_with_option)        { create(:product, option_types: [option_type], stores: [store]) }
  let!(:variant)                   { create(:variant, product: product_with_option, option_values: [option_value]) }
  let(:product)                    { create(:product, stores: [store]) }
  let!(:deleted_product)           { create(:product, deleted_at: Time.current - 1.day, stores: [store]) }
  let!(:discontinued_product)      { create(:product, discontinue_on: Time.current - 1.day, stores: [store]) }
  let!(:not_available_product)     { create(:product, available_on: nil, stores: [store]) }
  let!(:in_stock_product)          { create(:product_in_stock, stores: [store]) }
  let!(:not_backorderable_product) { create(:product_in_stock, :without_backorder, stores: [store]) }
  let!(:property)                  { create(:property) }
  let!(:new_property)              { create(:property) }
  let!(:product_with_property)     { create(:product, properties: [property], stores: [store]) }
  let!(:product_property)          { create(:product_property, property: new_property, product: product_with_property, value: 'Some Value') }

  before { Spree::Api::Config[:api_v2_per_page_limit] = 4 }

  describe 'products#index' do
    context 'with no params' do
      before { get '/api/v2/storefront/products' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns all products' do
        expect(json_response['data'].count).to eq store.products.available.count
        expect(json_response['data'].first).to have_type('product')
      end
    end

    context 'when product associated with two stores' do
      let!(:new_store_taxonomy) { create(:taxonomy, store: store) }
      let(:store2) { create(:store) }
      let(:taxonomy2) { create(:taxonomy, store: store2) }
      let!(:taxon2) { taxonomy2.root }

      before do
        product_with_taxon.stores << store2
        product_with_taxon.taxons << taxon2
      end

      shared_examples 'should not return not related taxon' do
        it do
          expect(json_response['data'][0]).not_to have_relationship(:taxons).with_data([{ 'id' => new_store_taxonomy.id.to_s, 'type' => 'taxon' }])
        end
      end

      context 'when current store is store' do
        before { get "/api/v2/storefront/products?filter[ids]=#{product_with_taxon.id}" }

        it 'should return only store taxons ralated to product', aggregate_failures: true do
          expect(json_response['data'][0]).to have_relationship(:taxons).with_data([{ 'id' => taxon.id.to_s, 'type' => 'taxon' }])
          expect(json_response['data'][0]).not_to have_relationship(:taxons).with_data([{ 'id' => taxon2.id.to_s, 'type' => 'taxon' }])
        end

        it_behaves_like 'should not return not related taxon'
      end

      context 'when current store is store2' do
        before do
          allow_any_instance_of(Spree::Api::V2::Storefront::ProductsController).to receive(:current_store).and_return(store2)
          get "/api/v2/storefront/products?filter[ids]=#{product_with_taxon.id}"
        end

        it 'should return only store2 taxons ralated to product', aggregate_failures: true do
          expect(json_response['data'][0]).to have_relationship(:taxons).with_data([{ 'id' => taxon2.id.to_s, 'type' => 'taxon' }])
          expect(json_response['data'][0]).not_to have_relationship(:taxons).with_data([{ 'id' => taxon.id.to_s, 'type' => 'taxon' }])
        end

        it_behaves_like 'should not return not related taxon'
      end
    end

    context 'current store' do
      let(:store_2) { create(:store) }
      let!(:product_from_another_store) { create(:product, stores: [store_2]) }

      before { get '/api/v2/storefront/products' }

      it 'returns products from this store only' do
        expect(json_response['data'].count).to eq store.products.available.count
        product_ids = json_response['data'].map(&:first).map(&:last)

        expect(product_ids).not_to include(product_from_another_store.id)
        expect(product_ids).to eq(store.products.available.ids.map(&:to_s))
      end
    end

    context 'with specified ids' do
      before { get "/api/v2/storefront/products?filter[ids]=#{products.first.id}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with specified ids' do
        expect(json_response['data'].count).to eq 1
        expect(json_response['data'].first).to have_id(products.first.id.to_s)
      end
    end

    context 'with specified skus' do
      before { get "/api/v2/storefront/products?filter[skus]=#{products.first.default_variant.sku}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with specified ids' do
        expect(json_response['data'].count).to eq 1
        expect(json_response['data'].first).to have_id(products.first.id.to_s)
      end
    end

    context 'with specified price range' do
      before { get "/api/v2/storefront/products?filter[price]=#{product_with_price.price.to_f},#{product_with_price.price.to_f + 0.04}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with specified price' do
        expect(json_response['data'].first).to have_id(product_with_price.id.to_s)
        expect(json_response['data'].first).to have_attribute(:price).with_value(product_with_price.price.to_f.to_s)
      end
    end

    context 'with specified taxon_ids' do
      before { get "/api/v2/storefront/products?filter[taxons]=#{product_with_taxon.taxons.first.id}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with specified taxons' do
        expect(json_response['data'].first).to have_id(product_with_taxon.id.to_s)
      end
    end

    context 'with specified name' do
      before { get "/api/v2/storefront/products?filter[name]=#{product_with_name.name}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with specified name' do
        expect(json_response['data'].first).to have_id(product_with_name.id.to_s)
        expect(json_response['data'].first).to have_attribute(:name).with_value(product_with_name.name)
      end
    end

    context 'with specified options' do
      before { get "/api/v2/storefront/products?filter[options][#{option_type.name}]=#{option_value.name}&include=option_types,variants.option_values" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with specified options' do
        expect(json_response['data'].first).to have_id(product_with_option.id.to_s)
        expect(json_response['included']).to   include(have_type('option_type').and(have_attribute(:name).with_value(option_type.name)))
        expect(json_response['included']).to   include(have_type('option_value').and(have_attribute(:name).with_value(option_value.name)))
      end
    end

    context 'with multiple specified options' do
      let!(:color) { create(:option_type, :color) }
      let!(:green_color) { create(:option_value, option_type: color, name: 'green') }
      let!(:white_color) { create(:option_value, option_type: color, name: 'white') }

      let!(:size) { create(:option_type, :size) }
      let!(:s_size) { create(:option_value, option_type: size, name: 's') }
      let!(:m_size) { create(:option_value, option_type: size, name: 'm') }

      let(:product_1) { create(:product, option_types: [color, size], stores: [store]) }
      let!(:variant_1) { create(:variant, product: product_1, option_values: [white_color, m_size]) }

      let(:product_2) { create(:product, option_types: [color, size], stores: [store]) }
      let!(:variant_2_1) { create(:variant, product: product_2, option_values: [green_color, s_size]) }
      let!(:variant_2_2) { create(:variant, product: product_2, option_values: [white_color, s_size]) }

      context 'for filters with products' do
        let(:options_filter) do
          [
            "filter[options][#{color.name}]=#{white_color.name}",
            "filter[options][#{size.name}]=#{m_size.name}"
          ].join('&')
        end

        before { get "/api/v2/storefront/products?#{options_filter}&include=option_types,variants.option_values" }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns products with specified options' do
          expect(json_response['data']).to include(have_id(product_1.id.to_s))
          expect(json_response['data']).not_to include(have_id(product_2.id.to_s))

          expect(json_response['included']).to include(have_type('option_type').and(have_attribute(:name).with_value(color.name)))
          expect(json_response['included']).to include(have_type('option_value').and(have_attribute(:name).with_value(white_color.name)))

          expect(json_response['included']).to include(have_type('option_type').and(have_attribute(:name).with_value(size.name)))
          expect(json_response['included']).to include(have_type('option_value').and(have_attribute(:name).with_value(m_size.name)))
        end
      end

      context 'for excluding filters' do
        let(:options_filter) do
          [
            "filter[options][#{color.name}]=#{green_color.name}",
            "filter[options][#{size.name}]=#{m_size.name}"
          ].join('&')
        end

        before { get "/api/v2/storefront/products?#{options_filter}&include=option_types,variants.option_values" }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns no products' do
          expect(json_response['data']).to be_empty
        end
      end
    end

    context 'with specified properties' do
      context 'using proper filter params' do
        before { get "/api/v2/storefront/products?filter[properties][#{property.filter_param}]=#{product_property.filter_param}&include=product_properties" }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns products with specified options' do
          expect(json_response['data'].first).to have_id(product_with_property.id.to_s)
          expect(json_response['included']).to include(have_type('product_property').and(have_attribute(:name).with_value(property.name)))
          expect(json_response['included']).to include(have_type('product_property').and(have_attribute(:value).with_value(product_property.value)))
          expect(json_response['included']).to include(have_type('product_property').and(have_attribute(:filter_param).with_value(product_property.filter_param)))
        end
      end

      context 'using property names and values' do
        before { get "/api/v2/storefront/products?filter[properties][#{property.name}]=#{product_property.value}&include=product_properties" }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns products with specified options' do
          expect(json_response['data'].first).to have_id(product_with_property.id.to_s)
        end
      end
    end

    context 'with specified multiple filters' do
      before { get "/api/v2/storefront/products?filter[name]=#{product_with_name.name}&filter[price]=#{product_with_name.price.to_f - 0.02},#{product_with_name.price.to_f + 0.02}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with specified name and price' do
        expect(json_response['data'].count).to eq 1
        expect(json_response['data'].first).to have_id(product_with_name.id.to_s)
      end
    end

    context 'with included deleted' do
      before { get '/api/v2/storefront/products?filter[show_deleted]=true' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with deleted products' do
        expect(json_response['data'].count).to eq 10
        expect(json_response['data'].pluck(:id)).to include(deleted_product.id.to_s)
      end
    end

    context 'with included discontinued' do
      before { get '/api/v2/storefront/products?filter[show_discontinued]=true' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with discontinued products' do
        expect(json_response['data'].count).to eq 11
        expect(json_response['data'].pluck(:id)).to include(discontinued_product.id.to_s)
      end
    end

    context 'with included discontinued and deleted' do
      before do
        get '/api/v2/storefront/products?filter[show_deleted]=true&filter[show_discontinued]=true'
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'returns available, deleted and discontinued products' do
        expect(json_response['data'].count).to eq 12
        expect(json_response['data'].pluck(:id)).to include(deleted_product.id.to_s, discontinued_product.id.to_s)
      end
    end

    context 'with show only stock' do
      before do
        get '/api/v2/storefront/products?filter[in_stock]=true'
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products in stock' do
        expect(json_response['data'].count).to eq 2
        expect(json_response['data'].pluck(:id)).to include(in_stock_product.id.to_s, not_backorderable_product.id.to_s)
      end
    end

    context 'with show only backorderable' do
      before do
        get '/api/v2/storefront/products?filter[backorderable]=true'
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products in stock' do
        expect(json_response['data'].count).to eq 8
        expect(json_response['data'].pluck(:id)).not_to include(not_backorderable_product.id.to_s)
      end
    end

    context 'with show only purchasable' do
      before do
        get '/api/v2/storefront/products?filter[purchasable]=true'
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'returns only purchasable products' do
        expect(json_response['data'].count).to eq 9
        expect(json_response['data'].pluck(:id)).to include(in_stock_product.id.to_s, not_backorderable_product.id.to_s)
      end
    end

    context 'sort products' do
      context 'sorting by price' do
        context 'ascending order' do
          before { get '/api/v2/storefront/products?sort=price' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by price' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.joins(master: :prices).select("#{store.products.table_name}.*, #{Spree::Price.table_name}.amount").distinct.order("#{Spree::Price.table_name}.amount").map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/storefront/products?sort=-price' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by price with descending order' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.joins(master: :prices).select("#{store.products.table_name}.*, #{Spree::Price.table_name}.amount").distinct.order("#{Spree::Price.table_name}.amount DESC").map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by name' do
        context 'A-Z' do
          before { get '/api/v2/storefront/products?sort=name' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by name' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.order(:name).map(&:id).map(&:to_s)
          end
        end

        context 'Z-A' do
          before { get '/api/v2/storefront/products?sort=-name' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by name with descending order' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.order(name: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by updated_at' do
        context 'ascending order' do
          before { get '/api/v2/storefront/products?sort=updated_at' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by updated_at' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.order(:updated_at).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/storefront/products?sort=-updated_at' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by updated_at with descending order' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.order(updated_at: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by created_at' do
        context 'ascending order' do
          before { get '/api/v2/storefront/products?sort=created_at' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by created_at' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.order(:created_at).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/storefront/products?sort=-created_at' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by created_at with descending order' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.order(created_at: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by available_on' do
        before { store.products.each_with_index { |p, i| p.update(available_on: Time.current - i.days) } }

        context 'ascending order' do
          before { get '/api/v2/storefront/products?sort=available_on' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by available_on' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.order(:available_on).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/storefront/products?sort=-available_on' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by available_on with descending order' do
            expect(json_response['data'].count).to      eq store.products.available.count
            expect(json_response['data'].pluck(:id)).to eq store.products.available.order(available_on: :desc).map(&:id).map(&:to_s)
          end
        end
      end
    end

    context 'paginate products' do
      context 'with specified pagination params' do
        context 'when per_page is between 1 and default value' do
          before { get '/api/v2/storefront/products?page=1&per_page=2' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns the default number of products' do
            expect(json_response['data'].count).to eq 2
          end

          it 'returns proper meta data' do
            expect(json_response['meta']['count']).to       eq 2
            expect(json_response['meta']['total_count']).to eq store.products.available.count
          end

          it 'returns proper links data' do
            expect(json_response['links']['self']).to include('/api/v2/storefront/products?page=1&per_page=2')
            expect(json_response['links']['next']).to include('/api/v2/storefront/products?page=2&per_page=2')
            expect(json_response['links']['prev']).to include('/api/v2/storefront/products?page=1&per_page=2')
          end
        end

        context 'when per_page is above the default value' do
          before { get '/api/v2/storefront/products?page=1&per_page=10' }

          it 'returns the default number of products' do
            expect(json_response['data'].count).to eq 9
          end
        end

        context 'when per_page is less than 0' do
          before { get '/api/v2/storefront/products?page=1&per_page=-1' }

          it 'returns the default number of products' do
            expect(json_response['data'].count).to eq 9
          end
        end

        context 'when per_page is equal 0' do
          before { get '/api/v2/storefront/products?page=1&per_page=0' }

          it 'returns the default number of products' do
            expect(json_response['data'].count).to eq 9
          end
        end
      end

      context 'without specified pagination params' do
        before { get '/api/v2/storefront/products' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount products' do
          expect(json_response['data'].count).to eq store.products.available.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq json_response['data'].count
          expect(json_response['meta']['total_count']).to eq store.products.available.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/storefront/products')
          expect(json_response['links']['next']).to include('/api/v2/storefront/products?page=1')
          expect(json_response['links']['prev']).to include('/api/v2/storefront/products?page=1')
        end
      end
    end

    context 'fetch products by curency param' do
      before { store.update(supported_currencies: 'USD,EUR,GBP') }

      context 'with default currency' do
        before { get '/api/v2/storefront/products?currency=USD' }

        it 'returns products' do
          expect(json_response['data']).not_to be_empty
          expect(json_response['data'][0]['attributes']['currency']).to eq 'USD'
          expect(json_response['data'].count).to eq store.products.available.count
        end
      end

      context 'with supported currency' do
        let(:product) { products.first }
        let(:currency) { 'EUR' }

        before do
          product.master.prices.create(currency: currency, amount: 99.90, compare_at_amount: 129.90)
          get "/api/v2/storefront/products?currency=#{currency}&include=default_variant"
        end

        it 'returns products with prices in that currency' do
          expect(json_response['data']).not_to be_empty
          expect(json_response['data'].count).to eq(1)
          expect(json_response['data'][0]['id']).to eq(product.id.to_s)
          expect(json_response['data'][0]['attributes']['currency']).to eq currency
          expect(json_response['data'][0]['attributes']['price']).to eq('99.9')
          expect(json_response['data'][0]['attributes']['display_price']).to eq('€99.90')
          expect(json_response['data'][0]['attributes']['compare_at_price']).to eq('129.9')
          expect(json_response['data'][0]['attributes']['display_compare_at_price']).to eq('€129.90')
          expect(json_response['included'][0]['id']).to eq(product.default_variant_id.to_s)
          expect(json_response['included'][0]['type']).to eq('variant')
          expect(json_response['included'][0]['attributes']['price']).to eq('99.9')
          expect(json_response['included'][0]['attributes']['display_price']).to eq('€99.90')
          expect(json_response['included'][0]['attributes']['compare_at_price']).to eq('129.9')
          expect(json_response['included'][0]['attributes']['display_compare_at_price']).to eq('€129.90')
        end
      end

      context 'without supported currency' do
        before { get '/api/v2/storefront/products?currency=PLN' }

        it 'returns results with default currency' do
          expect(json_response['data']).not_to be_empty
          expect(json_response['data'][0]['attributes']['currency']).to eq 'USD'
          expect(json_response['data'][0]['attributes']['display_price']).to match('$')
        end
      end
    end
  end

  describe 'products#show' do
    context 'with supported currency param' do
      before { get "/api/v2/storefront/products/#{product.slug}?currency=USD" }

      it_behaves_like 'returns 200 HTTP status'

      it 'return product with supported currency' do
        expect(json_response['data']).not_to be_empty
        expect(json_response['data']['id']).to eq(product.id.to_s)
        expect(json_response['data']['attributes']['currency']).to eq('USD')
      end
    end

    context 'with supported currency but without prices in that currency' do
      before do
        store.update(supported_currencies: 'USD,EUR,GBP')
        get "/api/v2/storefront/products/#{product.slug}?currency=EUR&include=default_variant"
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'returns empty prices' do
        expect(json_response['data']).not_to be_empty
        expect(json_response['data']['id']).to eq(product.id.to_s)
        expect(json_response['data']['attributes']['currency']).to eq('EUR')
        expect(json_response['data']['attributes']['price']).to be_nil
        expect(json_response['data']['attributes']['display_price']).to be_nil
        expect(json_response['data']['attributes']['compare_at_price']).to be_nil
        expect(json_response['data']['attributes']['display_compare_at_price']).to be_nil
        expect(json_response['included'][0]['id']).to eq(product.default_variant_id.to_s)
        expect(json_response['included'][0]['type']).to eq('variant')
        expect(json_response['included'][0]['attributes']['currency']).to eq('EUR')
        expect(json_response['included'][0]['attributes']['price']).to be_nil
        expect(json_response['included'][0]['attributes']['display_price']).to be_nil
        expect(json_response['included'][0]['attributes']['compare_at_price']).to be_nil
        expect(json_response['included'][0]['attributes']['display_compare_at_price']).to be_nil
      end
    end

    context 'without supported currency param' do
      before { get "/api/v2/storefront/products/#{product.slug}?currency=PLN" }

      it 'fallbacks to default currency' do
        expect(json_response['data']).not_to be_empty
        expect(json_response['data']['id']).to eq(product.id.to_s)
        expect(json_response['data']['attributes']['currency']).to eq('USD')
      end
    end

    context 'with non-existing product' do
      before { get '/api/v2/storefront/products/example' }

      it_behaves_like 'returns 404 HTTP status'
    end

    context 'with existing product' do
      before { get "/api/v2/storefront/products/#{product.slug}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns a valid JSON response' do
        expect(json_response['data']).to have_id(product.id.to_s)

        expect(json_response['data']).to have_type('product')

        expect(json_response['data']).to have_attribute(:name).with_value(product.name)
        expect(json_response['data']).to have_attribute(:description).with_value(product.description)
        expect(json_response['data']).to have_attribute(:price).with_value(product.price.to_s)
        expect(json_response['data']).to have_attribute(:currency).with_value(product.currency)
        expect(json_response['data']).to have_attribute(:display_price).with_value(product.display_price.to_s)
        expect(json_response['data']).to have_attribute(:available_on).with_value(product.available_on.as_json)
        expect(json_response['data']).to have_attribute(:slug).with_value(product.slug)
        expect(json_response['data']).to have_attribute(:meta_description).with_value(product.meta_description)
        expect(json_response['data']).to have_attribute(:meta_keywords).with_value(product.meta_keywords)
        expect(json_response['data']).to have_attribute(:updated_at).with_value(product.updated_at.as_json)
        expect(json_response['data']).to have_attribute(:purchasable).with_value(product.purchasable?)
        expect(json_response['data']).to have_attribute(:in_stock).with_value(product.in_stock?)
        expect(json_response['data']).to have_attribute(:backorderable).with_value(product.backorderable?)

        expect(json_response['data']).to have_relationships(
          :variants, :option_types, :product_properties, :default_variant
        )
      end
    end

    context 'with product from another store' do
      let(:store_2) { create(:store) }
      let(:product_from_another_store) { create(:product, stores: [store_2]) }

      before { get "/api/v2/storefront/products/#{product_from_another_store.slug}" }

      it_behaves_like 'returns 404 HTTP status'
    end
  end
end
