require 'spec_helper'

describe 'API V2 Platform Products Spec' do
  include_context 'Platform API v2'

  let(:bearer_token) { { 'Authorization' => valid_authorization } }

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
  let!(:not_available_product)     { create(:product, status: 'draft', stores: [store]) }
  let!(:in_stock_product)          { create(:product_in_stock, stores: [store]) }
  let!(:not_backorderable_product) { create(:product_in_stock, :without_backorder, stores: [store]) }
  let!(:property)                  { create(:property) }
  let!(:new_property)              { create(:property) }
  let!(:product_with_property)     { create(:product, stores: [store]) }
  let!(:product_property)          { create(:product_property, property: new_property, product: product_with_property, value: 'Some Value') }
  let!(:product_property2)          { create(:product_property, property: property, product: product_with_property, value: 'Some Value 2') }

  describe 'products#index' do
    context 'with no params' do
      before { get '/api/v2/platform/products', headers: bearer_token }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns all products' do
        expect(json_response['data'].count).to eq store.products.count
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
    end

    context 'current store' do
      let(:store_2) { create(:store) }
      let!(:product_from_another_store) { create(:product, stores: [store_2]) }

      before { get '/api/v2/platform/products', headers: bearer_token }

      it 'returns products from this store only' do
        expect(json_response['data'].count).to eq store.products.count
        product_ids = json_response['data'].pluck(:id)

        expect(product_ids).not_to include(product_from_another_store.id)
        expect(product_ids).to match_array(store.products.ids.map(&:to_s))
      end
    end

    context 'sort products' do
      context 'sorting by price' do
        before { store.products.each_with_index { |p, i| p.update(price: p.price + i) } }

        context 'ascending order' do
          before { get '/api/v2/platform/products?sort=price', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by price' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.joins(master: :prices).select("#{store.products.table_name}.*, #{Spree::Price.table_name}.amount").distinct.order("#{Spree::Price.table_name}.amount").map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/products?sort=-price', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by price with descending order' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.joins(master: :prices).select("#{store.products.table_name}.*, #{Spree::Price.table_name}.amount").distinct.order("#{Spree::Price.table_name}.amount DESC").map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by name' do
        context 'A-Z' do
          before { get '/api/v2/platform/products?sort=name', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by name' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(:name).map(&:id).map(&:to_s)
          end
        end

        context 'Z-A' do
          before { get '/api/v2/platform/products?sort=-name', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by name with descending order' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(name: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by updated_at' do
        context 'ascending order' do
          before { get '/api/v2/platform/products?sort=updated_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by updated_at' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(:updated_at).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/products?sort=-updated_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by updated_at with descending order' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(updated_at: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by created_at' do
        context 'ascending order' do
          before { get '/api/v2/platform/products?sort=created_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by created_at' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(:created_at).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/products?sort=-created_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by created_at with descending order' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(created_at: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by available_on' do
        before { store.products.each_with_index { |p, i| p.update(available_on: Time.current - i.days) } }

        context 'ascending order' do
          before { get '/api/v2/platform/products?sort=available_on', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by available_on' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(:available_on).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/products?sort=-available_on', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by available_on with descending order' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(available_on: :desc).map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by make_active_at' do
        before { store.products.each_with_index { |p, i| p.update(make_active_at: Time.current - i.days) } }

        context 'ascending order' do
          before { get '/api/v2/platform/products?sort=make_active_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by make_active_at' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(:make_active_at).map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/platform/products?sort=-make_active_at', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by make_active_at with descending order' do
            expect(json_response['data'].count).to      eq store.products.count
            expect(json_response['data'].pluck(:id)).to eq store.products.order(make_active_at: :desc).map(&:id).map(&:to_s)
          end
        end
      end
    end

    context 'paginate products' do
      context 'with specified pagination params' do
        context 'when per_page is between 1 and default value' do
          before { get '/api/v2/platform/products?page=1&per_page=2', headers: bearer_token }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns the default number of products' do
            expect(json_response['data'].count).to eq 2
          end

          it 'returns proper meta data' do
            expect(json_response['meta']['count']).to       eq 2
            expect(json_response['meta']['total_count']).to eq store.products.count
          end

          it 'returns proper links data' do
            expect(json_response['links']['self']).to include('/api/v2/platform/products?page=1&per_page=2')
            expect(json_response['links']['next']).to include('/api/v2/platform/products?page=2&per_page=2')
            expect(json_response['links']['prev']).to include('/api/v2/platform/products?page=1&per_page=2')
          end
        end

        context 'when per_page is above the default value' do
          before { get '/api/v2/platform/products?page=1&per_page=8', headers: bearer_token }

          it 'returns the per_page number of products' do
            expect(json_response['data'].count).to eq 8
          end
        end

        context 'when per_page is less than 0' do
          before { get '/api/v2/platform/products?page=1&per_page=-1', headers: bearer_token }

          it 'returns the max or default number of products' do
            expect(json_response['data'].count).to eq 11
          end
        end

        context 'when per_page is equal 0' do
          before { get '/api/v2/platform/products?page=1&per_page=0', headers: bearer_token }

          it 'returns the max or default number of products' do
            expect(json_response['data'].count).to eq 11
          end
        end
      end

      context 'without specified pagination params' do
        before { get '/api/v2/platform/products', headers: bearer_token }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount products' do
          expect(json_response['data'].count).to eq store.products.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq json_response['data'].count
          expect(json_response['meta']['total_count']).to eq store.products.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/platform/products')
          expect(json_response['links']['next']).to include('/api/v2/platform/products?page=1')
          expect(json_response['links']['prev']).to include('/api/v2/platform/products?page=1')
        end
      end
    end

    context 'fetch products by curency param' do
      before { store.update(supported_currencies: 'USD,EUR,GBP') }

      context 'with default currency' do
        before { get '/api/v2/platform/products?currency=USD', headers: bearer_token }

        it 'returns products' do
          expect(json_response['data']).not_to be_empty
          expect(json_response['data'][0]['attributes']['currency']).to eq 'USD'
          expect(json_response['data'].count).to eq store.products.count
        end
      end
    end
  end

  describe 'products#show' do
    context 'with product image data' do
      shared_examples 'returns product image data' do
        it 'returns product image data' do
          expect(json_response['data']['relationships']['images'].count).to eq(1)
          expect(json_response['included'].count).to eq(1)
          expect(json_response['included'].first['type']).to eq('image')
        end
      end

      let!(:image) { create(:image, viewable: product.master) }
      let(:image_json_data) { json_response['included'].first['attributes'] }

      before { get "/api/v2/platform/products/#{product.id}?include=images#{image_transformation_params}", headers: bearer_token }

      context 'when no image transformation params are passed' do
        let(:image_transformation_params) { '' }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns product image data'

        it 'returns product image' do
          expect(image_json_data['transformed_url']).to be_nil
        end
      end

      context 'when product image json returned' do
        let(:image_transformation_params) { '&image_transformation[size]=100x50&image_transformation[quality]=50' }

        it_behaves_like 'returns 200 HTTP status'
        it_behaves_like 'returns product image data'

        it 'returns product image' do
          expect(image_json_data['transformed_url']).not_to be_nil
        end
      end
    end
  end
end
