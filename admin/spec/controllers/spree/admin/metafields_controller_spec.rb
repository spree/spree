require 'spec_helper'

RSpec.describe Spree::Admin::MetafieldsController, type: :controller do
  render_views
  stub_authorization!

  let(:product) { create(:product) }
  let!(:metafield) { create(:metafield, owner: product, key: 'color', value: 'red', kind: 'string') }

  describe 'GET #edit' do
    subject { get :edit, params: { id: product.id, resource_type: 'Spree::Product' } }

    it 'assigns the resource' do
      subject
      expect(assigns(:resource)).to eq(product)
    end

    it 'assigns metafields' do
      subject
      expect(assigns(:metafields)).to include(metafield)
    end

    it 'renders the edit template' do
      subject
      expect(response).to render_template(:edit)
    end

    context 'with visibility filter' do
      let!(:private_metafield) { create(:metafield, owner: product, key: 'secret', value: 'value', visibility: 'private') }

      it 'filters metafields by visibility' do
        get :edit, params: { id: product.id, resource_type: 'Spree::Product', visibility: 'private' }
        expect(assigns(:metafields)).to include(private_metafield)
        expect(assigns(:metafields)).not_to include(metafield)
      end
    end

    context 'with different resource types' do
      let(:variant) { create(:variant) }

      it 'works with variants' do
        get :edit, params: { id: variant.id, resource_type: 'Spree::Variant' }
        expect(assigns(:resource)).to eq(variant)
      end
    end

    context 'with invalid resource type' do
      it 'raises RecordNotFound' do
        expect {
          get :edit, params: { id: product.id, resource_type: 'InvalidClass' }
        }.to raise_error(ActiveRecord::RecordNotFound, 'Resource type not found')
      end
    end
  end

  describe 'PUT #update' do
    let(:valid_params) do
      {
        id: product.id,
        resource_type: 'Spree::Product',
        product: {
          metafields_attributes: [
            { id: metafield.id, key: 'color', value: 'blue', kind: 'string', visibility: 'public' },
            { key: 'size', value: 'large', kind: 'string', visibility: 'public' }
          ]
        }
      }
    end

    context 'with valid parameters' do
      it 'updates existing metafields' do
        put :update, params: valid_params
        metafield.reload
        expect(metafield.value).to eq('blue')
      end

      it 'creates new metafields' do
        expect {
          put :update, params: valid_params
        }.to change(product.metafields, :count).by(1)
      end

      it 'redirects to edit page' do
        put :update, params: valid_params
        expect(response).to redirect_to(edit_admin_metafield_path(product, resource_type: 'Spree::Product'))
      end

      it 'sets success flash message' do
        put :update, params: valid_params
        expect(flash[:success]).to eq(Spree.t('metafields.messages.metafields_updated'))
      end
    end

    context 'with destroy flag' do
      let(:destroy_params) do
        {
          id: product.id,
          resource_type: 'Spree::Product',
          product: {
            metafields_attributes: [
              { id: metafield.id, _destroy: '1' }
            ]
          }
        }
      end

      it 'destroys metafields marked for destruction' do
        expect {
          put :update, params: destroy_params
        }.to change(product.metafields, :count).by(-1)
      end
    end

    context 'with different kinds' do
      let(:kind_params) do
        {
          id: product.id,
          resource_type: 'Spree::Product',
          product: {
            metafields_attributes: [
              { key: 'count', value: '42', kind: 'integer', visibility: 'public' },
              { key: 'active', value: 'true', kind: 'boolean', visibility: 'public' },
              { key: 'config', value: '{"theme": "dark"}', kind: 'json', visibility: 'public' }
            ]
          }
        }
      end

      it 'creates metafields with different kinds' do
        put :update, params: kind_params
        
        integer_field = product.metafields.find_by(key: 'count')
        boolean_field = product.metafields.find_by(key: 'active')
        json_field = product.metafields.find_by(key: 'config')

        expect(integer_field.kind).to eq('integer')
        expect(boolean_field.kind).to eq('boolean')
        expect(json_field.kind).to eq('json')
      end
    end

    context 'with different visibilities' do
      let(:visibility_params) do
        {
          id: product.id,
          resource_type: 'Spree::Product',
          product: {
            metafields_attributes: [
              { key: 'public_key', value: 'public_value', kind: 'string', visibility: 'public' },
              { key: 'private_key', value: 'private_value', kind: 'string', visibility: 'private' }
            ]
          }
        }
      end

      it 'creates metafields with different visibilities' do
        put :update, params: visibility_params
        
        public_field = product.metafields.find_by(key: 'public_key')
        private_field = product.metafields.find_by(key: 'private_key')

        expect(public_field.visibility).to eq('public')
        expect(private_field.visibility).to eq('private')
      end
    end
  end

  describe 'private methods' do
    controller do
      public :resource_class, :allowed_resource_class
    end

    describe '#resource_class' do
      it 'returns the correct class for valid resource types' do
        get :edit, params: { id: product.id, resource_type: 'Spree::Product' }
        expect(controller.resource_class).to eq(Spree::Product)
      end

      context 'with invalid resource type' do
        it 'raises RecordNotFound' do
          expect {
            get :edit, params: { id: product.id, resource_type: 'InvalidClass' }
          }.to raise_error(ActiveRecord::RecordNotFound, 'Resource type not found')
        end
      end
    end

    describe '#allowed_resource_class' do
      it 'includes expected resource classes' do
        get :edit, params: { id: product.id, resource_type: 'Spree::Product' }
        allowed_classes = controller.allowed_resource_class
        
        expect(allowed_classes).to include(Spree::Product)
        expect(allowed_classes).to include(Spree::Variant)
        expect(allowed_classes).to include(Spree::Order)
        expect(allowed_classes).to include(Spree::Store)
      end
    end
  end

  describe 'load_data' do
    context 'with Product' do
      it 'sets resource_name and back_path' do
        get :edit, params: { id: product.id, resource_type: 'Spree::Product' }
        expect(assigns(:resource_name)).to eq(product.name)
        expect(assigns(:back_path)).to eq(spree.edit_admin_product_path(product))
      end
    end

    context 'with Variant' do
      let(:variant) { create(:variant) }

      it 'sets correct back_path for variant' do
        get :edit, params: { id: variant.id, resource_type: 'Spree::Variant' }
        expect(assigns(:back_path)).to eq(spree.edit_admin_product_variant_path(variant.product, variant))
      end
    end

    context 'with Order' do
      let(:order) { create(:order) }

      it 'sets correct back_path for order' do
        get :edit, params: { id: order.id, resource_type: 'Spree::Order' }
        expect(assigns(:back_path)).to eq(spree.edit_admin_order_path(order))
      end
    end

    context 'with User' do
      let(:user) { create(:user) }

      it 'sets correct back_path for user' do
        get :edit, params: { id: user.id, resource_type: Spree.user_class.to_s }
        expect(assigns(:back_path)).to eq(spree.edit_admin_user_path(user))
      end
    end

    context 'with Store' do
      let(:store) { create(:store) }

      it 'sets correct back_path for store' do
        get :edit, params: { id: store.id, resource_type: 'Spree::Store' }
        expect(assigns(:back_path)).to eq(spree.edit_admin_store_path(store))
      end
    end

    context 'with Taxon' do
      let(:taxon) { create(:taxon) }

      it 'sets correct back_path for taxon' do
        get :edit, params: { id: taxon.id, resource_type: 'Spree::Taxon' }
        expect(assigns(:back_path)).to eq(spree.edit_admin_taxonomy_taxon_path(taxon.taxonomy, taxon))
      end
    end

    context 'with Taxonomy' do
      let(:taxonomy) { create(:taxonomy) }

      it 'sets correct back_path for taxonomy' do
        get :edit, params: { id: taxonomy.id, resource_type: 'Spree::Taxonomy' }
        expect(assigns(:back_path)).to eq(spree.admin_taxonomy_path(taxonomy))
      end
    end
  end
end