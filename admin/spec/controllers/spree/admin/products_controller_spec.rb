require 'spec_helper'

RSpec.describe Spree::Admin::ProductsController, type: :controller do
  stub_authorization!

  render_views

  let(:user) { create(:admin_user) }
  let(:store) { @default_store }

  before do
    allow(controller).to receive(:current_ability).and_call_original
  end

  describe '#GET #new' do
    it 'renders the new template' do
      get :new
      expect(response).to render_template(:new)
    end
  end

  describe 'GET #index' do
    it 'can find a product by SKU' do
      product = create(:product, sku: 'ABC123', stores: [store])
      get :index, params: { q: { sku_start: 'ABC123' } }
      expect(assigns[:collection]).not_to be_empty
      expect(assigns[:collection]).to include(product)
    end

    it 'can find a product by variant sku' do
      variant = create(:variant, sku: 'ABC123', is_master: false)
      product = create(:product, stores: [store], variants: [variant])
      get :index, params: { q: { multi_search: 'ABC123' } }
      expect(assigns[:collection]).not_to be_empty
      expect(assigns[:collection]).to include(product)
    end

    it 'searches by product kind' do
      shipping_category = create(:shipping_category, name: 'digital')
      product = create(:product, sku: 'ABC123', stores: [store], shipping_category: shipping_category)

      get :index, params: { q: { shipping_category_id_eq: shipping_category.id.to_s } }

      expect(assigns[:collection]).not_to be_empty
      expect(assigns[:collection]).to eq([product])
    end

    it 'searches based on taxons' do
      category_1 = create(:taxon)
      category_2 = create(:taxon)

      product_1 = create(:product, stores: [store], taxons: [category_1])
      product_2 = create(:product, stores: [store], taxons: [category_2])

      get :index, params: { q: { taxons_id_in: [category_1.id, category_2.id] } }

      expect(assigns[:collection]).to contain_exactly(product_1, product_2)
    end

    it 'searches for products without category' do
      create(:product, stores: [store], taxons: [create(:taxon)])
      product = create(:product, stores: [store], taxons: [])

      get :index, params: { q: { taxons_id_in: [' '] } }

      expect(assigns[:collection]).to contain_exactly(product)
    end

    context 'with views' do
      render_views

      it 'can perform multi search' do
        get :index, params: {
          'q' => {
            'status_eq' => 'active',
            'multi_search' => 'anchor',
            'classifications_taxon_id_in' => ['8b03b40e-094f-4803-8704-20ac02f9c167', '42e63c13-dbe7-483f-8237-3b0207145fed'],
            'shipping_category_id_eq' => '8b03b40e-094f-4803-8704-20ac02f9c167',
            'tags_name_in' => ['awesome'],
            'deleted_at_null' => '1',
            'not_discontinue' => '1'
          }
        }

        expect(response).to be_successful
      end
    end
  end

  describe 'POST #search' do
    let!(:product1) { create(:product, name: 'Product 1') }
    let!(:product2) { create(:product, name: 'Product 2') }
    let!(:product3) { create(:product, name: 'Product 3') }

    context 'when query is blank' do
      it 'returns a 200 status code' do
        get :search, params: { q: '' }, format: :turbo_stream
        expect(response).to have_http_status(:ok)
      end

      it 'returns an empty response body' do
        get :search, params: { q: '' }, format: :turbo_stream
        expect(response.body).to be_blank
      end
    end

    context 'when query is less than 3 characters' do
      it 'returns a 200 status code' do
        get :search, params: { q: 'ab' }, format: :turbo_stream
        expect(response).to have_http_status(:ok)
      end

      it 'returns an empty response body' do
        get :search, params: { q: 'ab' }, format: :turbo_stream
        expect(response.body).to be_blank
      end
    end

    context 'when query is valid' do
      it 'returns a 200 status code' do
        get :search, params: { q: 'Product' }, format: :turbo_stream
        expect(response).to have_http_status(:ok)
      end

      it 'renders the search_results partial' do
        get :search, params: { q: 'Product' }, format: :turbo_stream
        expect(response).to render_template(partial: 'spree/admin/products/_search_results')
      end

      it 'assigns the products matching the query to @products' do
        get :search, params: { q: 'Product' }, format: :turbo_stream
        expect(assigns(:products)).to match_array([product1, product2, product3])
      end

      context 'when omit_ids parameter is present' do
        it 'excludes the products with the given ids' do
          get :search, params: { q: 'Product', omit_ids: "#{product1.id},#{product2.id}" }, format: :turbo_stream
          expect(assigns(:products)).to match_array([product3])
        end
      end

      context 'when limit parameter is present' do
        it 'limits the number of products returned' do
          get :search, params: { q: 'Product', limit: 2 }, format: :turbo_stream
          expect(assigns(:products).size).to eq(2)
        end
      end
    end
  end

  describe 'POST #create' do
    subject { post :create, params: { product: product_params } }

    let(:stock_location) { create(:stock_location) }
    let(:other_stock_location) { create(:stock_location) }

    let(:shipping_category) { create(:shipping_category, name: 'Default') }
    let(:tax_category) { create(:tax_category, name: 'Clothing') }

    context 'without variants' do
      let(:product_params) do
        {
          name: 'Product',
          sku: 'SKU',
          barcode: 'BARCODE',
          weight: 10,
          height: 10,
          width: 10,
          depth: 10,
          dimensions_unit: 'cm',
          weight_unit: 'kg',
          shipping_category_id: shipping_category.id,
          tax_category_id: tax_category.id,
          meta_title: 'Amazing Product',
          meta_description: 'This is an amazing product'
        }
      end

      it 'creates product correctly' do
        subject

        product = Spree::Product.last
        expect(product.sku).to eq 'SKU'
        expect(product.barcode).to eq 'BARCODE'
        expect(product.weight).to eq 10
        expect(product.height).to eq 10
        expect(product.width).to eq 10
        expect(product.depth).to eq 10
        expect(product.dimensions_unit).to eq 'cm'
        expect(product.weight_unit).to eq 'kg'
        expect(product.stores).to eq [store]

        expect(product.shipping_category).to eq shipping_category
        expect(product.tax_category).to eq tax_category
        expect(product.meta_title).to eq 'Amazing Product'
        expect(product.meta_description).to eq 'This is an amazing product'
      end

      context 'with multi-currency pricing' do
        before do
          product_params[:master_attributes] = {}
          product_params[:master_attributes][:prices_attributes] = {
            '0' => { currency: 'EUR', amount: 10, compare_at_amount: 20 },
            '1' => { currency: 'USD', amount: 20, compare_at_amount: 30 }
          }
        end

        it 'creates product correctly' do
          subject

          product = Spree::Product.last

          expect(product.master.prices.count).to eq 2
          expect(product.master.price_in('EUR').amount).to eq 10
          expect(product.master.price_in('USD').amount).to eq 20
          expect(product.master.price_in('EUR').compare_at_amount).to eq 20
          expect(product.master.price_in('USD').compare_at_amount).to eq 30
        end
      end
    end

    context 'with variants' do
      let!(:option_type) { create(:option_type, name: 'Color', presentation: 'Color') }
      let(:product_params) do
        {
          name: 'Product',
          variants_attributes: {
            '0' => {
              prices_attributes: {
                '0': { currency: 'PLN', amount: 10 },
                '1': { currency: 'USD', amount: 20 }
              },
              stock_items_attributes: {
                '0' => {
                  count_on_hand: 10,
                  stock_location_id: stock_location.id,
                }
              },
              options: [
                {
                  id: nil,
                  name: 'Color',
                  position: 1,
                  option_value_presentation: 'Red',
                  option_value_name: nil
                },
                {
                  id: nil,
                  name: 'Not existing option',
                  position: 2,
                  option_value_presentation: 'Not existing value',
                  option_value_name: nil
                }
              ]
            },
            '3' => {
              prices_attributes: {
                '0': { currency: 'PLN', amount: 44 },
                '1': { currency: 'USD', amount: 55 }
              },
              stock_items_attributes: {
                '0' => {
                  count_on_hand: 200,
                  stock_location_id: other_stock_location.id,
                }
              },
              options: [
                {
                  id: nil,
                  name: 'Color',
                  position: 1,
                  option_value_presentation: 'Blue',
                  option_value_name: nil
                },
                {
                  id: nil,
                  name: 'Not existing option',
                  position: 2,
                  option_value_presentation: 'Not existing value2',
                  option_value_name: nil
                }
              ]
            }
          },
          shipping_category_id: shipping_category.id
        }
      end

      context 'when track_inventory is false' do
        before do
          product_params[:track_inventory] = '0'
        end

        it 'does not create stock items' do
          subject

          product = Spree::Product.last

          expect(product.stock_items.reload.count).to eq(0)
        end
      end

      context 'when prices are not present' do
        before do
          product_params[:variants_attributes]['0'][:prices_attributes] = {
            '0': { currency: 'PLN', amount: nil },
            '1': { currency: 'USD', amount: 20 },
            '2': { currency: 'EUR', amount: 30 }
          }
          product_params[:variants_attributes]['3'][:prices_attributes] = {
            '0': { currency: 'PLN', amount: 44 },
            '1': { currency: 'USD', amount: 55 },
            '2': { currency: 'EUR', amount: 66 }
          }
        end

        it 'does not create price for that currency' do
          subject

          product = Spree::Product.last
          expect(product.variants.count).to eq 2

          variant = product.variants.first
          expect(variant.prices.reload.count).to eq 2

          pln_price = variant.price_in('PLN')
          expect(pln_price.amount).to be nil
          expect(pln_price.persisted?).to be false

          expect(variant.price_in('USD').amount).to eq 20
          expect(variant.price_in('EUR').amount).to eq 30
          expect(variant.options_text).to eq 'Color: Red, Not existing option: Not existing value'
          expect(variant.stock_items.first.count_on_hand).to eq 10
          expect(variant.stock_items.first.stock_location).to eq stock_location

          other_variant = product.variants.last
          expect(other_variant.prices.reload.count).to eq 3

          expect(other_variant.price_in('PLN').amount).to eq 44
          expect(other_variant.price_in('USD').amount).to eq 55
          expect(other_variant.price_in('EUR').amount).to eq 66
          expect(other_variant.options_text).to eq 'Color: Blue, Not existing option: Not existing value2'
          expect(other_variant.stock_items.first.count_on_hand).to eq 200
          expect(other_variant.stock_items.first.stock_location).to eq other_stock_location
        end
      end

      it 'creates product correctly' do
        subject

        product = Spree::Product.last
        expect(product.variants.count).to eq 2

        variant = product.variants.first
        expect(variant.price_in('PLN').amount).to eq 10
        expect(variant.price_in('USD').amount).to eq 20
        expect(variant.options_text).to eq 'Color: Red, Not existing option: Not existing value'
        expect(variant.stock_items.first.count_on_hand).to eq 10
        expect(variant.stock_items.first.stock_location).to eq stock_location

        other_variant = product.variants.last
        expect(other_variant.price_in('PLN').amount).to eq 44
        expect(other_variant.price_in('USD').amount).to eq 55
        expect(other_variant.options_text).to eq 'Color: Blue, Not existing option: Not existing value2'
        expect(other_variant.stock_items.first.count_on_hand).to eq 200
        expect(other_variant.stock_items.first.stock_location).to eq other_stock_location
      end
    end

    context 'with stock items' do
      let(:product_params) do
        {
          name: 'Product',
          master_attributes: {
            track_inventory: true,
            stock_items_attributes: {
              '0' => {
                count_on_hand: 10,
                stock_location_id: stock_location.id,
                backorderable: false
              },
              '1' => {
                count_on_hand: 5,
                stock_location_id: other_stock_location.id,
                backorderable: true
              }
            }
          },
          shipping_category_id: shipping_category.id
        }
      end

      it 'correctly assign stock items' do
        subject

        product = Spree::Product.last

        stock_item = product.master.stock_items.first
        expect(stock_item.count_on_hand).to eq 10
        expect(stock_item.stock_location).to eq stock_location
        expect(stock_item.backorderable).to be false

        other_stock_item = product.master.stock_items.last
        expect(other_stock_item.count_on_hand).to eq 5
        expect(other_stock_item.stock_location).to eq other_stock_location
        expect(other_stock_item.backorderable).to be true

        expect(product.master.track_inventory).to be true
      end
    end

    context 'with product properties' do
      let!(:property_1) { create(:property, name: 'material', presentation: 'Material') }
      let!(:property_2) { create(:property, name: 'short_description', presentation: 'Short description') }
      let!(:property_3) { create(:property, name: 'care', presentation: 'Care') }

      let(:product_params) do
        {
          name: 'Product',
          product_properties_attributes: {
            '0' => {
              property_id: property_1.id,
              value: 'Wool'
            },
            '1' => {
              property_id: property_2.id,
              value: 'Short description'
            },
            '2' => {
              property_id: property_3.id,
              value: ''
            }
          },
          shipping_category_id: shipping_category.id
        }
      end

      it 'creates product properties correctly' do
        subject

        product = Spree::Product.last
        expect(product.properties.count).to eq 2
        expect(product.property('material')).to eq 'Wool'
        expect(product.property('short_description')).to eq 'Short description'
      end
    end

    context 'with multiple stores' do
      let(:store_2) { create(:store) }

      let(:product_params) do
        {
          name: 'Product',
          store_ids: [store.id, store_2.id],
          shipping_category_id: shipping_category.id
        }
      end

      it 'assigns product to requests stores plus current store' do
        subject

        product = Spree::Product.last
        expect(product.stores).to eq [store, store_2]
      end

      context 'with empty store_ids' do
        let(:product_params) do
          {
            name: 'Product',
            store_ids: [],
            shipping_category_id: shipping_category.id
          }
        end

        it 'assigns product to current store' do
          subject

          product = Spree::Product.last
          expect(product.stores).to eq [store]
        end
      end
    end
  end

  describe '#GET #edit' do
    let!(:product) { create(:product, stores: [store], status: 'active') }

    it 'renders the edit template' do
      get :edit, params: { id: product.to_param }
      expect(response).to render_template(:edit)
    end

    context 'with variants' do
      let!(:variant) { create(:variant, product: product) }

      it 'renders the edit template' do
        get :edit, params: { id: product.to_param }
        expect(response).to render_template(:edit)
      end
    end
  end

  describe 'PUT #update' do
    let!(:product) { create(:product, stores: [store], status: 'active') }
    let(:product_params) { { status: 'draft', make_active_at: Time.current.beginning_of_day } }
    let(:send_request) do
      put :update, params: {
        id: product.to_param,
        product: product_params
      }
    end

    describe 'master variant inventory' do
      let(:product_params) do
        {
          master_attributes: {
            id: product.master_id,
            stock_items_attributes: {
              '0' => {
                id: product.master.stock_items.first.id,
                stock_location_id: product.master.stock_items.first.stock_location_id,
                count_on_hand: 123,
                backorderable: '1'
              }
            }
          }
        }
      end

      it 'updates the stock of the master variant' do
        send_request
        expect(product.master.reload.total_on_hand).to eq(123)
        expect(product.master).to be_backorderable
      end
    end

    describe 'master variant prices' do
      let(:product_params) do
        {
          master_attributes: {
            id: product.master_id,
            prices_attributes: {
              '0' => {
                currency: 'PLN',
                amount: 10,
                id: product.master.price_in('PLN')&.id
              },
              '1' => {
                currency: 'USD',
                amount: 20,
                id: product.master.price_in('USD')&.id
              }
            }
          }
        }
      end

      it 'updates the prices of the master variant' do
        send_request
        expect(product.master.price_in('PLN').amount).to eq 10
        expect(product.master.price_in('USD').amount).to eq 20
      end

      context 'when price is not present' do
        before do
          product_params[:master_attributes][:prices_attributes]['0'][:amount] = nil
        end

        it 'removes the price' do
          send_request
          expect(product.master.price_in('PLN').amount).to be_nil
          expect(product.master.price_in('PLN').id).to be_nil
          expect(product.master.price_in('USD').amount).to eq 20
          expect(product.master.price_in('USD').id).to be_present
        end
      end
    end

    context 'adding variants to existing product' do
      let(:stock_location) { create(:stock_location) }
      let(:other_stock_location) { create(:stock_location) }
      let(:new_option_type) { create(:option_type, name: 'Material', presentation: 'Fabric') }
      let(:silk_option_value) { create(:option_value, name: 'Silk', option_type: new_option_type, presentation: 'Silk') }

      let(:product_params) do
        {
          name: 'Product',
          variants_attributes: {
            '0' => {
              prices_attributes: {
                '0': { currency: 'PLN', amount: 10 },
                '1': { currency: 'USD', amount: 20 }
              },
              stock_items_attributes: {
                '0' => {
                  count_on_hand: 10,
                  stock_location_id: stock_location.id,
                }
              },
              options: [
                {
                  id: nil,
                  name: 'Color',
                  position: 1,
                  option_value_presentation: 'Red',
                  option_value_name: nil
                },
                {
                  id: nil,
                  name: 'Not existing option',
                  position: 2,
                  option_value_presentation: 'Not existing value',
                  option_value_name: nil
                },
                {
                  id: new_option_type.id,
                  name: 'Fabric',
                  position: 3,
                  option_value_presentation: silk_option_value.presentation,
                  option_value_name: silk_option_value.name
                }
              ]
            },
            '3' => {
              prices_attributes: {
                '0': { currency: 'PLN', amount: 44 },
                '1': { currency: 'USD', amount: 55 }
              },
              stock_items_attributes: {
                '0' => {
                  count_on_hand: 200,
                  stock_location_id: other_stock_location.id,
                }
              },
              options: [
                {
                  id: nil,
                  name: 'Color',
                  position: 1,
                  option_value_presentation: 'Blue',
                  option_value_name: nil
                },
                {
                  id: nil,
                  name: 'Not existing option',
                  position: 2,
                  option_value_presentation: 'Not existing value2',
                  option_value_name: nil
                },
                {
                  id: new_option_type.id,
                  name: 'Fabric',
                  position: 3,
                  option_value_presentation: 'Cotton',
                  option_value_name: nil
                }
              ]
            }
          }
        }
      end

      it 'creates variants correctly' do
        send_request

        expect(product.variants.reload.count).to eq 2

        variant = product.variants.first
        expect(variant.price_in('PLN').amount).to eq 10
        expect(variant.price_in('USD').amount).to eq 20
        expect(variant.options_text).to eq 'Color: Red, Not existing option: Not existing value, and Fabric: Silk'
        expect(variant.stock_items.first.count_on_hand).to eq 10
        expect(variant.stock_items.first.stock_location).to eq stock_location

        other_variant = product.variants.last
        expect(other_variant.price_in('PLN').amount).to eq 44
        expect(other_variant.price_in('USD').amount).to eq 55
        expect(other_variant.options_text).to eq 'Color: Blue, Not existing option: Not existing value2, and Fabric: Cotton'
        expect(other_variant.stock_items.first.count_on_hand).to eq 200
        expect(other_variant.stock_items.first.stock_location).to eq other_stock_location
      end

      context "when option is missing id attribute" do
        let(:product_params) do
          {
            name: 'Product',
            variants_attributes: {
              '0' => {
                prices_attributes: {
                  '0': { currency: 'PLN', amount: 10 },
                  '1': { currency: 'USD', amount: 20 }
                },
                stock_items_attributes: {
                  '0' => {
                    count_on_hand: 10,
                    stock_location_id: stock_location.id,
                  }
                },
                options: [
                  option_without_id_attribute
                ]
              }
            }
          }
        end

        let(:option_without_id_attribute) do
          {
            id: nil,
            name: 'Color',
            position: 1,
            value: 'Red'
          }.except(:id)
        end

        it 'raises an error' do
          expect {
            send_request
          }.to raise_error(ActionController::ParameterMissing)
        end
      end
    end

    context 'updating existing variants' do
      let(:color_option_type) { create(:option_type, name: 'Color', presentation: 'Color', products: [product]) }
      let(:size_option_type) { create(:option_type, name: 'Size', presentation: 'Size', products: [product]) }
      let(:red_option_value) { create(:option_value, name: 'Red', option_type: color_option_type) }
      let(:blue_option_value) { create(:option_value, name: 'Blue', option_type: color_option_type) }
      let(:small_option_value) { create(:option_value, name: 'Small', option_type: size_option_type) }
      let(:large_option_value) { create(:option_value, name: 'Large', option_type: size_option_type) }

      let(:variant1) { create(:variant, product: product, option_values: [red_option_value, small_option_value], price: 100) }
      let(:variant2) { create(:variant, product: product, option_values: [blue_option_value, large_option_value], price: 100) }
      let(:variant3) { create(:variant, product: product, option_values: [red_option_value, large_option_value], price: 100) }

      let!(:variant1_price_pln) { create(:price, variant: variant1, currency: 'PLN', amount: 100) }
      let!(:variant2_price_pln) { create(:price, variant: variant2, currency: 'PLN', amount: 200) }
      let!(:variant3_price_pln) { create(:price, variant: variant3, currency: 'PLN', amount: 300) }

      let(:variant1_stock_item) { variant1.stock_items.first }
      let(:variant2_stock_item) { variant2.stock_items.first }
      let(:variant3_stock_item) { variant3.stock_items.first }

      let(:product_params) do
        {
          name: 'Product',
          variants_attributes: {
            '0' => {
              prices_attributes: {
                '0' => { currency: 'PLN', amount: 10, id: variant1.price_in('PLN')&.id },
                '1' => { currency: 'USD', amount: 20, id: variant1.price_in('USD')&.id }
              },
              id: variant1.id,
              stock_items_attributes: {
                '0' => {
                  id: variant1_stock_item.id,
                  count_on_hand: 10,
                  stock_location_id: variant1_stock_item.stock_location_id,
                }
              },
              options: [
                {
                  id: nil,
                  name: 'Color',
                  position: 1,
                  option_value_presentation: red_option_value.presentation,
                  option_value_name: red_option_value.name
                },
                {
                  id: nil,
                  name: 'Size',
                  position: 2,
                  option_value_presentation: small_option_value.presentation,
                  option_value_name: small_option_value.name
                }
              ]
            },
            '1' => {
              prices_attributes: {
                '0' => { currency: 'PLN', amount: 30, id: variant2.price_in('PLN')&.id },
                '1' => { currency: 'USD', amount: 40, id: variant2.price_in('USD')&.id }
              },
              id: variant2.id,
              stock_items_attributes: {
                '0' => {
                  id: variant2_stock_item.id,
                  count_on_hand: 20,
                  stock_location_id: variant2_stock_item.stock_location_id,
                }
              },
              options: [
                {
                  id: nil,
                  name: 'Color',
                  position: 1,
                  option_value_presentation: blue_option_value.presentation,
                  option_value_name: blue_option_value.name
                },
                {
                  id: nil,
                  name: 'Size',
                  position: 2,
                  option_value_presentation: large_option_value.presentation,
                  option_value_name: large_option_value.name
                }
              ]
            },
            '2' => {
              prices_attributes: {
                '0' => { currency: 'PLN', amount: 30, id: variant3.price_in('PLN')&.id },
                '1' => { currency: 'USD', amount: 40, id: variant3.price_in('USD')&.id }
              },
              id: variant3.id,
              stock_items_attributes: {
                '0' => {
                  id: variant3_stock_item.id,
                  count_on_hand: 30,
                  stock_location_id: variant3_stock_item.stock_location_id,
                }
              },
              options: [
                {
                  id: nil,
                  name: 'Color',
                  position: 1,
                  option_value_presentation: red_option_value.presentation,
                  option_value_name: red_option_value.name
                },
                {
                  id: nil,
                  name: 'Size',
                  position: 2,
                  option_value_presentation: large_option_value.presentation,
                  option_value_name: large_option_value.name
                }
              ]
            }
          }
        }
      end

      context 'when price is not present' do
        before do
          product_params[:variants_attributes]['2'][:prices_attributes]['0'][:amount] = nil
        end

        it 'removes the price' do
          send_request

          expect(variant3.price_in('PLN').amount).to be_nil
          expect(variant3.price_in('PLN').id).to be_nil
          expect(variant3.price_in('USD').amount).to eq 40
          expect(variant3.price_in('USD').id).to be_present
        end
      end

      it 'updates the variants' do
        send_request

        expect(variant1.price_in('PLN').amount).to eq 10
        expect(variant1.price_in('USD').amount).to eq 20
        expect(variant2.price_in('PLN').amount).to eq 30
        expect(variant2.price_in('USD').amount).to eq 40

        expect(variant1_stock_item.reload.count_on_hand).to eq 10
        expect(variant2_stock_item.reload.count_on_hand).to eq 20
      end

      context 'updating option types position' do
        let(:product_params) do
          {
            variants_attributes: {
              '0' => {
                id: variant1.id,
                prices_attributes: {
                  '0': { currency: 'PLN', amount: 10, id: variant1.price_in('PLN')&.id },
                  '1': { currency: 'USD', amount: 20, id: variant1.price_in('USD')&.id }
                },
                options: [
                  {
                    id: nil,
                    name: 'Size',
                    position: 1,
                    option_value_presentation: small_option_value.presentation,
                    option_value_name: small_option_value.name
                  },
                  {
                    id: nil,
                    name: 'Color',
                    position: 2,
                    option_value_presentation: red_option_value.presentation,
                    option_value_name: red_option_value.name
                  }
                ]
              },
              '1' => {
                id: variant2.id,
                prices_attributes: {
                  '0': { currency: 'PLN', amount: 30, id: variant2.price_in('PLN')&.id },
                  '1': { currency: 'USD', amount: 40, id: variant2.price_in('USD')&.id }
                },
                options: [
                  {
                    id: nil,
                    name: 'Size',
                    position: 1,
                    option_value_presentation: large_option_value.presentation,
                    option_value_name: large_option_value.name
                  },
                  {
                    id: nil,
                    name: 'Color',
                    position: 2,
                    option_value_presentation: blue_option_value.presentation,
                    option_value_name: blue_option_value.name
                  }
                ]
              }
            }
          }
        end

        before do
          product.product_option_types.find_by(option_type_id: color_option_type.id).update(position: 1)
          product.product_option_types.find_by(option_type_id: size_option_type.id).update(position: 2)
        end

        it 'updates the variants' do
          send_request

          expect(variant1.price_in('PLN').amount).to eq 10
          expect(variant1.price_in('USD').amount).to eq 20
          expect(variant2.price_in('PLN').amount).to eq 30
          expect(variant2.price_in('USD').amount).to eq 40

          expect(product.product_option_types.find_by(option_type_id: size_option_type.id).position).to eq 1
          expect(product.product_option_types.find_by(option_type_id: color_option_type.id).position).to eq 2
        end
      end

      context 'when option was removed' do
        let(:product_params) do
          {
            variants_attributes: {
              '0' => {
                id: variant1.id,
                price: { 'PLN' => 10, 'USD' => 20 },
                options: [
                  {
                    id: nil,
                    name: 'Size',
                    position: 1,
                    option_value_presentation: small_option_value.presentation,
                    option_value_name: small_option_value.name
                  }
                ],
                stock_items_attributes: {
                  '0' => {
                    id: variant1_stock_item.id,
                    count_on_hand: 20,
                    stock_location_id: variant1_stock_item.stock_location_id,
                  }
                },
              },
              '1' => {
                id: variant2.id,
                price: { 'PLN' => 30, 'USD' => 40 },
                stock_items_attributes: {
                  '0' => {
                    id: variant2_stock_item.id,
                    count_on_hand: 20,
                    stock_location_id: variant2_stock_item.stock_location_id,
                  }
                },
                options: [
                  {
                    id: nil,
                    name: 'Size',
                    position: 1,
                    option_value_presentation: large_option_value.presentation,
                    option_value_name: large_option_value.name
                  }
                ]
              }
            }
          }
        end

        it 'removes the option type from the product' do
          send_request

          expect(product.option_types.pluck(:name)).to eq(['size'])
        end
      end

      context 'when variant is no longer present in the params' do
        before do
          product_params[:variants_attributes].delete('0')
        end

        it 'removes the variant' do
          send_request

          expect(product.reload.variant_ids).to eq([variant2.id, variant3.id])
        end
      end

      context 'when all variants are removed' do
        before do
          product_params.delete(:variants_attributes)
        end

        it 'removes the product variants' do
          send_request

          expect(product.reload.variant_ids).to be_empty
          expect(product.option_types).to be_empty
        end
      end
    end

    context 'setting track_inventory to false' do
      let(:product_params) do
        {
          track_inventory: '0',
          master_attributes: {
            id: product.master.id,
            stock_items_attributes: {
              '0' => {
                id: product.master.stock_items.first.id,
                stock_location_id: product.master.stock_items.first.stock_location_id,
                count_on_hand: 100
              }
            }
          }
        }
      end

      before do
        product.update(track_inventory: true)
        create(:stock_item, count_on_hand: 20, variant: product.master)
      end

      it 'updates stock item count on hand to 0' do
        expect(product.master.stock_items.reload.count).to be > 0

        send_request

        expect(product.reload.track_inventory).to be(false)
        expect(product.master.stock_items.reload.first.count_on_hand).to eq(0)
      end
    end

    context 'with product properties' do
      let!(:property_1) { create(:property, name: 'material', presentation: 'Material') }
      let!(:property_2) { create(:property, name: 'short_description', presentation: 'Short description') }
      let!(:property_3) { create(:property, name: 'care', presentation: 'Care') }

      let(:product_property_1) { create(:product_property, product: product, property: property_1, value: 'Wool') }
      let(:product_property_2) { create(:product_property, product: product, property: property_2, value: 'Short description') }

      let(:product_params) do
        {
          product_properties_attributes: {
            '0' => {
              id: product_property_1.id,
              property_id: property_1.id,
              value: 'Better Wool'
            },
            '1' => {
              id: product_property_2.id,
              property_id: property_2.id,
              value: ''
            },
            '2' => {
              property_id: property_3.id,
              value: 'new value'
            }
          }
        }
      end

      it 'updates 1 product property, creates 1 product property and destroys 1 product property' do
        send_request

        product = Spree::Product.last
        expect(product.properties.count).to eq 2
        expect(product.property('material')).to eq 'Better Wool'
        expect(product.property('short_description')).to be_nil
        expect(product.property('care')).to eq 'new value'
      end
    end

    context 'with multi-store taxon preservation' do
      let(:other_store) { create(:store) }
      let(:store_taxonomy) { create(:taxonomy, store: store) }
      let(:other_store_taxonomy) { create(:taxonomy, store: other_store) }
      let(:store_taxon) { create(:taxon, taxonomy: store_taxonomy, name: 'Current Store Category') }
      let(:new_store_taxon) { create(:taxon, taxonomy: store_taxonomy, name: 'New Store Category') }
      let(:other_store_taxon) { create(:taxon, taxonomy: other_store_taxonomy, name: 'Other Store Category') }

      before do
        product.update(stores: [store, other_store])
        product.taxons << [store_taxon, other_store_taxon]
      end

      let(:product_params) do
        {
          name: 'Updated Product',
          taxon_ids: [new_store_taxon.id]
        }
      end

      it 'preserves taxons from other stores when updating' do
        expect(product.taxons).to include(store_taxon, other_store_taxon)

        send_request

        product.reload
        expect(product.taxons).to include(other_store_taxon)
        expect(product.taxons).to include(new_store_taxon)
        expect(product.taxons).not_to include(store_taxon)
      end

      context 'when removing all taxons from current store' do
        let(:product_params) do
          {
            name: 'Updated Product',
            taxon_ids: ['']
          }
        end

        it 'preserves taxons from other stores' do
          send_request

          product.reload
          expect(product.taxons).to include(other_store_taxon)
          expect(product.taxons).not_to include(store_taxon)
        end
      end

      context 'with multiple other stores' do
        let(:third_store) { create(:store) }
        let(:third_store_taxonomy) { create(:taxonomy, store: third_store) }
        let(:third_store_taxon) { create(:taxon, taxonomy: third_store_taxonomy, name: 'Third Store Category') }

        before do
          product.stores << third_store
          product.taxons << third_store_taxon
        end

        it 'preserves taxons from all other stores' do
          send_request

          product.reload
          expect(product.taxons).to include(other_store_taxon, third_store_taxon, new_store_taxon)
          expect(product.taxons).not_to include(store_taxon)
          expect(product.taxons.count).to eq 3
        end
      end
    end

    it 'will successfully update product' do
      send_request
      expect(flash[:success]).to eq("Product #{product.name.inspect} has been successfully updated!")
      expect(product.reload.status).to eq('draft')
      expect(product.make_active_at).to eq(Time.current.beginning_of_day)
    end

    describe 'removing last Label and Tag when param not sent' do
      before do
        product.update(tag_list: ['Tag 1'], label_list: ['Label 1'])
        send_request
      end

      it 'removes tags successfully' do
        expect(Spree::Product.find(product.id).tag_list).to be_empty
      end

      it 'removes labels successfully' do
        expect(Spree::Product.find(product.id).label_list).to be_empty
      end
    end

    describe 'failing to update product' do
      let(:product_params) { { name: '' } }

      context 'using empty name' do
        before { send_request }

        it 'renders the edit page' do
          expect(response).to render_template(:edit)
          expect(response).to have_http_status(:unprocessable_entity)
        end

        it 'renders the error' do
          expect(response.body).to include('Name can&#39;t be blank')
        end
      end
    end

    describe 'using same slug' do
      let!(:product) { create(:product, name: 'Existing Product', slug: 'existing-product', stores: [store]) }
      let!(:product_2) { create(:product, name: 'Existing Product', slug: 'existing-product-2', stores: [store]) }
      let(:product_params) { { slug: 'existing-product-2' } }

      before do
        allow(SecureRandom).to receive(:uuid).and_return('2dc1cfdf-81fe-4983-8709-ef6ee843c41d')
        send_request
      end

      it 'updates the slug with uuid' do
        expect(product.reload.slug).to eq('existing-product-2-2dc1cfdf-81fe-4983-8709-ef6ee843c41d')
      end
    end
  end

  describe 'PUT #clone' do
    subject(:clone_request) { put :clone, params: { id: product.id } }

    let!(:product) { create(:product, name: 'Product to clone', stores: [store], status: 'active') }
    let(:cloned_product) { Spree::Product.find_by(name: 'COPY OF Product to clone') }

    context 'when cloning succeeds' do
      it 'redirects to the cloned product page' do
        clone_request

        expect(flash[:success]).to eq('Product has been cloned')
        expect(response).to redirect_to(spree.edit_admin_product_path(cloned_product.slug))
      end
    end

    context 'when cloning fails' do
      before do
        duplicator_service = double(call: nil)
        expect(Spree::Products::Duplicator).to receive(:new).and_return(duplicator_service)
        expect(duplicator_service).to receive(:call).with(product: product).and_return(
          double(:result, success?: false, value: nil, error: double(:error, value: 'Something went wrong'))
        )
      end

      it 'responds with an error' do
        clone_request

        expect(flash[:error]).to eq('Product could not be cloned. Reason: Something went wrong')
        expect(response).to redirect_to(spree.edit_admin_product_path(product.slug))
      end
    end
  end

  describe 'POST #bulk_status_update' do
    let(:product) { create(:product, stores: [store], status: status) }
    let(:status) { :draft }
    let(:send_request) { put :bulk_status_update, params: { ids: [product.id], status: 'active' }, format: :turbo_stream }

    shared_examples 'updates status to active' do |status|
      let(:status) { status }

      it 'updates status to active' do
        expect(product.status).to eq status.to_s
        send_request
        expect(product.reload.active?).to be(true)
      end
    end

    Spree::Product.state_machine.states.map(&:name).each do |status|
      context "when product is in #{status} status" do
        it_behaves_like 'updates status to active', status
      end
    end
  end

  describe 'PUT #bulk_add_tags' do
    let(:product) { create(:product, stores: [store], status: :active) }
    let(:product2) { create(:product, stores: [store], status: :active) }
    let(:send_request) do
      put :bulk_add_tags, params: { ids: [product.id, product2.id], tags: ['tag1', 'tag2', 'tag3'] }, format: :turbo_stream
    end

    it 'adds tags to products' do
      send_request
      expect(product.reload.tag_list).to eq(['tag1', 'tag2', 'tag3'])
      expect(product2.reload.tag_list).to eq(['tag1', 'tag2', 'tag3'])
    end
  end

  describe 'PUT #bulk_remove_tags' do
    let(:product) { create(:product, stores: [store], status: :active, tag_list: ['tag1', 'tag2', 'tag3']) }
    let(:product2) { create(:product, stores: [store], status: :active, tag_list: ['tag1', 'tag2', 'tag3']) }
    let(:send_request) do
      put :bulk_remove_tags, params: { ids: [product.id, product2.id], tags: ['tag1', 'tag2', 'tag3'] }, format: :turbo_stream
    end

    it 'removes tags from products' do
      send_request
      expect(product.reload.tag_list).to eq([])
      expect(product2.reload.tag_list).to eq([])
    end
  end

  describe 'PUR #bulk_remove_from_taxons' do
    let(:product_ids) { [product.id, product3.id] }
    let(:taxon_ids) { [category.id, category2.id, category3.id] }

    let(:product) { create(:product, stores: [store], status: :active, taxons: [category, category2]) }
    let(:product2) { create(:product, stores: [store], status: :active, taxons: [category]) }
    let(:product3) { create(:product, stores: [store], status: :active, taxons: [category, category3]) }
    let(:product4) { create(:product, stores: [store], status: :active, taxons: [category, category2]) }

    let!(:category) { create(:taxon) }
    let!(:category2) { create(:taxon) }
    let!(:category3) { create(:taxon) }

    let(:send_request) do
      put :bulk_remove_from_taxons, params: { ids: product_ids, taxon_ids: taxon_ids }, format: :turbo_stream
    end

    it { expect { send_request }.to change { product.reload.taxons } }

    it 'unassigns the category properly' do
      send_request
      expect(product.reload.taxons).to eq []
      expect(product3.reload.taxons).to eq []
    end

    it 'touches the products' do
      product_old_updated_at = product.updated_at
      product3_old_updated_at = product3.updated_at

      send_request

      expect(product.reload.updated_at).not_to eq(product_old_updated_at)
      expect(product3.reload.updated_at).not_to eq(product3_old_updated_at)
    end

    it 'touches the taxons' do
      category_old_updated_at = category.reload.updated_at
      category2_old_updated_at = category2.reload.updated_at
      category3_old_updated_at = category3.reload.updated_at

      send_request

      expect(category.reload.updated_at).not_to eq(category_old_updated_at)
      expect(category2.reload.updated_at).not_to eq(category2_old_updated_at)
      expect(category3.reload.updated_at).not_to eq(category3_old_updated_at)
    end

    it 'reassigns the positions of existing products on the taxon list' do
      send_request

      expect(product2.reload.classifications.last.position).to eq(1)

      expect(product4.reload.classifications.find_by(taxon_id: category.id).position).to eq(2)
      expect(product4.reload.classifications.find_by(taxon_id: category2.id).position).to eq(1)
    end

    context 'for empty list of taxons and products' do
      let(:product_ids) { [] }
      let(:taxon_ids) { [] }

      it 'changes nothing' do
        send_request

        expect(product.reload.taxons).to contain_exactly(category, category2)
        expect(product3.reload.taxons).to contain_exactly(category, category3)
      end
    end

    describe 'auto matching taxons' do
      let(:product_ids) { [product, product2, product3, product4].pluck(:id) }

      let!(:product) { create(:product, stores: [store], status: :active) }
      let!(:product2) { create(:product, stores: [store], status: :active) }
      let!(:product3) { create(:product, stores: [store], status: :archived) }
      let!(:product4) { create(:product, stores: [store], status: :draft, deleted_at: Time.current) }

      before do
        Spree::Taxon.delete_all
      end

      context 'on a store with automatic taxons' do
        let!(:taxon_1) { create(:automatic_taxon) }
        let!(:taxon_2) { create(:taxon) }

        it 'auto matches taxons in bulk' do
          expect { send_request }.
            to have_enqueued_job(Spree::Products::AutoMatchTaxonsJob).
            on_queue(Spree.queues.taxons).
            exactly(:twice)

          jobs = Spree::Products::AutoMatchTaxonsJob.queue_adapter.enqueued_jobs.last(2)
          expect(jobs.map { |job| job['arguments'] }).to contain_exactly(
            [product.id],
            [product2.id]
          )
        end
      end

      context 'on a store without any automatic taxons' do
        let!(:taxon_1) { create(:taxon) }

        it 'skips auto matching taxons' do
          expect { send_request }.not_to have_enqueued_job(Spree::Products::AutoMatchTaxonsJob)
        end
      end
    end
  end

  describe 'PUT #bulk_add_to_taxons' do
    let(:product_ids) { [product.id, product2.id] }
    let(:taxon_ids) { [category.id] }

    let(:product) { create(:product, stores: [store], status: :active) }
    let(:product2) { create(:product, stores: [store], status: :active) }

    let(:category) { create(:taxon) }

    let(:send_request) do
      put :bulk_add_to_taxons, params: { ids: product_ids, taxon_ids: taxon_ids }, format: :turbo_stream
    end

    it { expect { send_request }.to change { product.reload.taxons } }

    it 'assigns the category properly' do
      send_request
      expect(product.reload.taxons).to contain_exactly(category)
      expect(product2.reload.taxons).to contain_exactly(category)
    end

    it 'assigns the product positions on the taxon list' do
      send_request

      expect(product.reload.classifications.last.position).to eq(1)
      expect(product2.reload.classifications.last.position).to eq(2)
    end

    it 'touches the products' do
      product_old_updated_at = product.updated_at
      product2_old_updated_at = product2.updated_at

      send_request

      expect(product.reload.updated_at).not_to eq(product_old_updated_at)
      expect(product2.reload.updated_at).not_to eq(product2_old_updated_at)
    end

    it 'touches the taxons' do
      category_old_updated_at = category.reload.updated_at

      send_request

      expect(category.reload.updated_at).not_to eq(category_old_updated_at)
    end

    context 'for empty list of taxons and products' do
      let(:product_ids) { [] }
      let(:taxon_ids) { [] }

      it 'changes nothing' do
        send_request
        expect(product.reload.taxons).to be_empty
      end
    end

    describe 'auto matching taxons' do
      let(:product_ids) { [product, product2, product3, product4].pluck(:id) }

      let!(:product3) { create(:product, stores: [store], status: :archived) }
      let!(:product4) { create(:product, stores: [store], status: :draft, deleted_at: Time.current) }

      before do
        product
        product2

        Spree::Taxon.delete_all
      end

      context 'on a store with automatic taxons' do
        let!(:taxon_1) { create(:automatic_taxon) }
        let!(:taxon_2) { create(:taxon) }

        it 'auto matches taxons in bulk' do
          expect { send_request }.
            to have_enqueued_job(Spree::Products::AutoMatchTaxonsJob).
            on_queue(Spree.queues.taxons).
            exactly(:twice)

          jobs = Spree::Products::AutoMatchTaxonsJob.queue_adapter.enqueued_jobs.last(2)
          expect(jobs.map { |job| job['arguments'] }).to contain_exactly(
            [product.id],
            [product2.id]
          )
        end
      end

      context 'on a store without any automatic taxons' do
        let!(:taxon_1) { create(:taxon) }

        it 'skips auto matching taxons' do
          expect { send_request }.not_to have_enqueued_job(Spree::Products::AutoMatchTaxonsJob)
        end
      end
    end
  end

  describe 'GET #bulk_modal' do
    context 'as admin' do
      it 'renders modal' do
        get :bulk_modal

        expect(response).to render_template('bulk_modal')
      end
    end
  end

  describe 'in_stock/out_of_stock' do
    let!(:in_stock_product) { create(:product) }
    let!(:in_stock_variant) { create(:variant, product: in_stock_product) }

    let!(:out_of_stock_product) { create(:product) }
    let!(:out_of_stock_variant) { create(:variant, product: out_of_stock_product) }

    before do
      in_stock_product.stock_items.update(count_on_hand: 10, backorderable: false)
      out_of_stock_product.stock_items.update(count_on_hand: 0, backorderable: false)
    end

    it 'returns only in stock products' do
      get :index, params: { q: { in_stock_items: 1 } }
      expect(assigns(:products).to_a).to eq([in_stock_product])
    end

    it 'returns only out of stock products' do
      get :index, params: { q: { out_of_stock_items: 1 } }
      expect(assigns(:products).to_a).to eq([out_of_stock_product])
    end
  end
end
