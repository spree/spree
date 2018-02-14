require 'spec_helper'

module Spree
  describe Api::V1::VariantsController, type: :controller do
    render_views

    let(:option_value) { create(:option_value) }
    let!(:product) { create(:product) }
    let!(:variant) do
      variant = product.master
      variant.option_values << option_value
      variant
    end

    let!(:base_attributes) { Api::ApiHelpers.variant_attributes }
    let!(:show_attributes) { base_attributes.dup.push(:in_stock, :display_price) }
    let!(:new_attributes) { base_attributes }

    before do
      stub_authentication!
    end

    describe '#variant_includes' do
      let(:variants_includes_list) do
        [{ option_values: :option_type }, :product, :default_price, :images, { stock_items: :stock_location }]
      end

      it { expect(controller).to receive(:variant_includes).and_return(variants_includes_list) }
      after { api_get :index }
    end

    it 'adds for_currency_and_available_price_amount scope to variants list' do
      expect(Spree::Variant).to receive(:for_currency_and_available_price_amount).
        and_return(Spree::Variant.for_currency_and_available_price_amount)
      api_get :index
    end

    it 'can see a paginated list of variants' do
      api_get :index
      first_variant = json_response['variants'].first
      expect(first_variant).to have_attributes(show_attributes)
      expect(first_variant['stock_items']).to be_present
      expect(json_response['count']).to eq(1)
      expect(json_response['current_page']).to eq(1)
      expect(json_response['pages']).to eq(1)
    end

    it 'can control the page size through a parameter' do
      create(:variant)
      api_get :index, per_page: 1
      expect(json_response['count']).to eq(1)
      expect(json_response['current_page']).to eq(1)
      expect(json_response['pages']).to eq(3)
    end

    it 'can query the results through a parameter' do
      expected_result = create(:variant, sku: 'FOOBAR')
      api_get :index, q: { sku_cont: 'FOO' }
      expect(json_response['count']).to eq(1)
      expect(json_response['variants'].first['sku']).to eq expected_result.sku
    end

    it 'variants returned contain option values data' do
      api_get :index
      option_values = json_response['variants'].last['option_values']
      expect(option_values.first).to have_attributes([:name,
                                                      :presentation,
                                                      :option_type_name,
                                                      :option_type_id])
    end

    it 'variants returned contain images data' do
      variant.images.create!(attachment: image('thinking-cat.jpg'))

      api_get :index

      expect(json_response['variants'].last).to have_attributes([:images])
      expect(json_response['variants'].first['images'].first).to have_attributes([:attachment_file_name,
                                                                                  :attachment_width,
                                                                                  :attachment_height,
                                                                                  :attachment_content_type,
                                                                                  :mini_url,
                                                                                  :small_url,
                                                                                  :product_url,
                                                                                  :large_url])
    end

    it 'variants returned do not contain cost price data' do
      api_get :index
      expect(json_response['variants'].first.key?(:cost_price)).to eq false
    end

    # Regression test for #2141
    context 'a deleted variant' do
      before do
        variant.update_column(:deleted_at, Time.current)
      end

      it 'is not returned in the results' do
        api_get :index
        expect(json_response['variants'].count).to eq(0)
      end

      it 'is not returned even when show_deleted is passed' do
        api_get :index, show_deleted: true
        expect(json_response['variants'].count).to eq(0)
      end
    end

    context 'pagination' do
      before { create(:variant) }

      it 'can select the next page of variants' do
        api_get :index, page: 2, per_page: 1
        expect(json_response['variants'].first).to have_attributes(show_attributes)
        expect(json_response['total_count']).to eq(3)
        expect(json_response['current_page']).to eq(2)
        expect(json_response['pages']).to eq(3)
      end
    end

    it 'can see a single variant' do
      api_get :show, id: variant.to_param
      expect(json_response).to have_attributes(show_attributes)
      expect(json_response['stock_items']).to be_present
      option_values = json_response['option_values']
      expect(option_values.first).to have_attributes([:name,
                                                      :presentation,
                                                      :option_type_name,
                                                      :option_type_id])
    end

    it 'can see a single variant with images' do
      variant.images.create!(attachment: image('thinking-cat.jpg'))

      api_get :show, id: variant.to_param

      expect(json_response).to have_attributes(show_attributes + [:images])
      option_values = json_response['option_values']
      expect(option_values.first).to have_attributes([:name,
                                                      :presentation,
                                                      :option_type_name,
                                                      :option_type_id])
    end

    it 'can learn how to create a new variant' do
      api_get :new
      expect(json_response['attributes']).to eq(new_attributes.map(&:to_s))
      expect(json_response['required_attributes']).to be_empty
    end

    it 'cannot create a new variant if not an admin' do
      api_post :create, variant: { sku: '12345' }
      assert_unauthorized!
    end

    it 'cannot update a variant' do
      api_put :update, id: variant.to_param, variant: { sku: '12345' }
      assert_not_found!
    end

    it 'cannot delete a variant' do
      api_delete :destroy, id: variant.to_param
      assert_not_found!
      expect { variant.reload }.not_to raise_error
    end

    context 'as an admin' do
      sign_in_as_admin!
      let(:resource_scoping) { { product_id: variant.product.to_param } }

      # Test for #2141
      context 'deleted variants' do
        before do
          variant.update_columns(deleted_at: Time.current, discontinue_on: Time.current + 1)
        end

        it 'are visible by admin' do
          api_get :index, show_deleted: 1
          expect(json_response['variants'].count).to eq(1)
        end
      end

      it 'can create a new variant' do
        other_value = create(:option_value)
        api_post :create, variant: {
          sku: '12345',
          price: '20',
          option_value_ids: [option_value.id, other_value.id]
        }

        expect(json_response).to have_attributes(new_attributes)
        expect(response.status).to eq(201)
        expect(json_response['sku']).to eq('12345')
        expect(json_response['price']).to match '20'

        option_value_ids = json_response['option_values'].map { |o| o['id'] }
        expect(option_value_ids).to match_array [option_value.id, other_value.id]

        expect(variant.product.variants.count).to eq(1)
      end

      it 'can update a variant' do
        api_put :update, id: variant.to_param, variant: { sku: '12345' }
        expect(response.status).to eq(200)
      end

      it 'can delete a variant' do
        api_delete :destroy, id: variant.to_param
        expect(response.status).to eq(204)
        expect { Spree::Variant.find(variant.id) }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'variants returned contain cost price data' do
        api_get :index
        expect(json_response['variants'].first.key?(:cost_price)).to eq true
      end
    end
  end
end
