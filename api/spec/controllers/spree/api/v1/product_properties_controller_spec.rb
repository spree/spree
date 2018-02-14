require 'spec_helper'
require 'shared_examples/protect_product_actions'

module Spree
  describe Api::V1::ProductPropertiesController, type: :controller do
    render_views

    let!(:product) { create(:product) }
    let!(:property_1) { product.product_properties.create(property_name: 'My Property 1', value: 'my value 1', position: 0) }

    let(:attributes) { [:id, :product_id, :property_id, :value, :property_name] }
    let(:resource_scoping) { { product_id: product.to_param } }

    before do
      product.product_properties.create(property_name: 'My Property 2', value: 'my value 2', position: 1) # property_2
      stub_authentication!
    end

    context 'if product is deleted' do
      before do
        product.update_column(:deleted_at, 1.day.ago)
      end

      it 'can not see a list of product properties' do
        api_get :index
        expect(response.status).to eq(404)
      end
    end

    it 'can see a list of all product properties' do
      api_get :index
      expect(json_response['product_properties'].count).to eq 2
      expect(json_response['product_properties'].first).to have_attributes(attributes)
    end

    it 'can control the page size through a parameter' do
      api_get :index, per_page: 1
      expect(json_response['product_properties'].count).to eq(1)
      expect(json_response['current_page']).to eq(1)
      expect(json_response['pages']).to eq(2)
    end

    it 'can query the results through a parameter' do
      Spree::ProductProperty.last.update_attribute(:value, 'loose')
      property = Spree::ProductProperty.last
      api_get :index, q: { value_cont: 'loose' }
      expect(json_response['count']).to eq(1)
      expect(json_response['product_properties'].first['value']).to eq property.value
    end

    it 'can search for product properties' do
      product.product_properties.create(property_name: 'Shirt Size')
      product.product_properties.create(property_name: 'Shirt Weight')
      api_get :index, q: { property_name_cont: 'size' }
      expect(json_response['product_properties'].first['property_name']).to eq('Shirt Size')
      expect(json_response['product_properties'].first).to have_attributes(attributes)
      expect(json_response['count']).to eq(1)
    end

    it 'can see a single product_property' do
      api_get :show, id: property_1.property_name
      expect(json_response).to have_attributes(attributes)
    end

    it 'can learn how to create a new product property' do
      api_get :new
      expect(json_response['attributes']).to eq(attributes.map(&:to_s))
      expect(json_response['required_attributes']).to be_empty
    end

    it 'cannot create a new product property if not an admin' do
      api_post :create, product_property: { property_name: 'My Property 3' }
      assert_unauthorized!
    end

    it 'cannot update a product property' do
      api_put :update, id: property_1.property_name, product_property: { value: 'my value 456' }
      assert_unauthorized!
    end

    it 'cannot delete a product property' do
      api_delete :destroy, id: property_1.to_param, property_name: property_1.property_name
      assert_unauthorized!
      expect { property_1.reload }.not_to raise_error
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'can create a new product property' do
        expect do
          api_post :create, product_property: { property_name: 'My Property 3', value: 'my value 3' }
        end.to change(product.product_properties, :count).by(1)
        expect(json_response).to have_attributes(attributes)
        expect(response.status).to eq(201)
      end

      context 'when product property does not exist' do
        it 'cannot update product property and responds 404' do
          api_put :update, id: 'does not exist', product_property: { value: 'new value' }
          expect(response.status).to eq(404)
        end
      end

      context 'when product property exists' do
        context 'when product property is valid' do
          it 'responds 200' do
            api_put :update, id: property_1.property_name, product_property: { value: 'my value 456' }
            expect(response.status).to eq(200)
          end
        end

        context 'when product property is invalid' do
          before do
            expect_any_instance_of(Spree::ProductProperty).to receive(:update_attributes).and_return false
          end

          it 'responds 422' do
            api_put :update, id: property_1.property_name, product_property: { value: 'hello' }
            expect(response.status).to eq(422)
          end
        end
      end

      context 'when product property does not exist' do
        it 'cannot delete product property and responds 404' do
          api_delete :destroy, id: 'does not exist'
          expect(response.status).to eq(404)
        end
      end

      context 'when product property exists' do
        it 'can delete a product property' do
          api_delete :destroy, id: property_1.property_name
          expect(response.status).to eq(204)
          expect { property_1.reload }.to raise_error(ActiveRecord::RecordNotFound)
        end
      end
    end

    context 'with product identified by id' do
      let(:resource_scoping) { { product_id: product.id } }

      it 'can see a list of all product properties' do
        api_get :index
        expect(json_response['product_properties'].count).to eq 2
        expect(json_response['product_properties'].first).to have_attributes(attributes)
      end

      it 'can see a single product_property by id' do
        api_get :show, id: property_1.id
        expect(json_response).to have_attributes(attributes)
      end
    end
  end
end
