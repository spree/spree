require 'spec_helper'

describe 'API V2 Storefront Products Spec', type: :request do
  let!(:products)              { create_list(:product, 5) }
  let(:taxon)                  { create(:taxon) }
  let(:product_with_taxon)     { create(:product, taxons: [taxon]) }
  let(:product_with_name)      { create(:product, name: 'Test Product') }
  let(:product_with_price)     { create(:product, price: 13.44) }
  let!(:option_type)           { create(:option_type) }
  let!(:option_value)          { create(:option_value, option_type: option_type) }
  let(:product_with_option)    { create(:product, option_types: [option_type]) }
  let!(:variant)               { create(:variant, product: product_with_option, option_values: [option_value]) }
  let(:product)                { create(:product) }
  let!(:deleted_product)       { create(:product, deleted_at: Time.current - 1.day) }
  let!(:discontinued_product)  { create(:product, discontinue_on: Time.current - 1.day) }
  let!(:not_available_product) { create(:product, available_on: nil) }

  describe 'products#index' do
    context 'with no params' do
      before { get '/api/v2/storefront/products' }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns all products' do
        expect(json_response['data'].count).to eq Spree::Product.available.count
        expect(json_response['data'].first).to have_type('product')
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

    context 'with specified multiple filters' do
      before { get "/api/v2/storefront/products?filter[name]=#{product_with_name.name}&filter[price]=#{product_with_name.price.to_f - 0.02},#{product_with_name.price.to_f + 0.02}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with specified name and price' do
        expect(json_response['data'].count).to eq 1
        expect(json_response['data'].first).to have_id(product_with_name.id.to_s)
      end
    end

    context 'with included deleted' do
      before { get "/api/v2/storefront/products?filter[show_deleted]=#{true}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with deleted products' do
        expect(json_response['data'].count).to eq 7
        expect(json_response['data'].pluck(:id)).to include(deleted_product.id.to_s)
      end
    end

    context 'with included discontinued' do
      before { get "/api/v2/storefront/products?filter[show_discontinued]=#{true}" }

      it_behaves_like 'returns 200 HTTP status'

      it 'returns products with discontinued products' do
        expect(json_response['data'].count).to eq 8
        expect(json_response['data'].pluck(:id)).to include(discontinued_product.id.to_s)
      end
    end

    context 'with included discontinued and deleted' do
      before do
        get "/api/v2/storefront/products?filter[show_deleted]=#{true}&filter[show_discontinued]=#{true}"
      end

      it_behaves_like 'returns 200 HTTP status'

      it 'returns available, deleted and discontinued products' do
        expect(json_response['data'].count).to eq 9
        expect(json_response['data'].pluck(:id)).to include(deleted_product.id.to_s, discontinued_product.id.to_s)
      end
    end

    context 'sort products' do
      context 'sorting by price' do
        context 'ascending order' do
          before { get '/api/v2/storefront/products?sort=price' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by price' do
            expect(json_response['data'].count).to      eq Spree::Product.available.count
            expect(json_response['data'].pluck(:id)).to eq Spree::Product.available.joins(master: :prices).select("#{Spree::Product.table_name}.*, #{Spree::Price.table_name}.amount").distinct.order("#{Spree::Price.table_name}.amount").map(&:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/storefront/products?sort=-price' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by price with descending order' do
            expect(json_response['data'].count).to      eq Spree::Product.available.count
            expect(json_response['data'].pluck(:id)).to eq Spree::Product.available.joins(master: :prices).select("#{Spree::Product.table_name}.*, #{Spree::Price.table_name}.amount").distinct.order("#{Spree::Price.table_name}.amount DESC").map(&:id).map(&:to_s)
          end
        end
      end

      context 'sorting by updated_at' do
        context 'ascending order' do
          before { get '/api/v2/storefront/products?sort=updated_at' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by updated_at' do
            expect(json_response['data'].count).to      eq Spree::Product.available.count
            expect(json_response['data'].pluck(:id)).to eq Spree::Product.available.order(:updated_at).pluck(:id).map(&:to_s)
          end
        end

        context 'descending order' do
          before { get '/api/v2/storefront/products?sort=-updated_at' }

          it_behaves_like 'returns 200 HTTP status'

          it 'returns products sorted by updated_at with descending order' do
            expect(json_response['data'].count).to      eq Spree::Product.available.count
            expect(json_response['data'].pluck(:id)).to eq Spree::Product.available.order(updated_at: :desc).pluck(:id).map(&:to_s)
          end
        end
      end
    end

    context 'paginate products' do
      context 'with specified pagination params' do
        before { get '/api/v2/storefront/products?page=1&per_page=2' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount products' do
          expect(json_response['data'].count).to eq 2
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq 2
          expect(json_response['meta']['total_count']).to eq Spree::Product.available.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/storefront/products?page=1&per_page=2')
          expect(json_response['links']['next']).to include('/api/v2/storefront/products?page=2&per_page=2')
          expect(json_response['links']['prev']).to include('/api/v2/storefront/products?page=1&per_page=2')
        end
      end

      context 'without specified pagination params' do
        before { get '/api/v2/storefront/products' }

        it_behaves_like 'returns 200 HTTP status'

        it 'returns specified amount products' do
          expect(json_response['data'].count).to eq Spree::Product.available.count
        end

        it 'returns proper meta data' do
          expect(json_response['meta']['count']).to       eq json_response['data'].count
          expect(json_response['meta']['total_count']).to eq Spree::Product.available.count
        end

        it 'returns proper links data' do
          expect(json_response['links']['self']).to include('/api/v2/storefront/products')
          expect(json_response['links']['next']).to include('/api/v2/storefront/products?page=1')
          expect(json_response['links']['prev']).to include('/api/v2/storefront/products?page=1')
        end
      end
    end
  end

  describe 'products#show' do
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
  end
end
