require 'spec_helper'

describe Spree::Admin::RelationsController, type: :controller do
  stub_authorization!

  let(:user)     { create(:user) }
  let!(:product) { create(:product) }
  let!(:other1)  { create(:product) }

  let!(:relation_type) { create(:relation_type) }
  let!(:relation) { create(:relation, relatable: product, related_to: other1, relation_type: relation_type, position: 0) }

  before do
    user.generate_spree_api_key!
    allow(controller).to receive(:spree_current_user).and_return(user)
  end

  context '.model_class' do
    it 'responds to model_class as Spree::Relation' do
      expect(controller.send(:model_class)).to eq Spree::Relation
    end
  end

  describe 'with JS' do
    let(:valid_params) do
      {
        format: :js,
        product_id: product.id,
        relation: {
          related_to_id: other1.id,
          relation_type_id: relation_type.id
        },
        token: user.spree_api_key
      }
    end

    context '#create' do
      it 'is not routable' do
        post :create, params: valid_params
        expect(response.status).to be(200)
      end

      it 'returns success with valid params' do
        expect {
          post :create, params: valid_params
        }.to change(Spree::Relation, :count).by(1)
      end

      it 'raises error with invalid params' do
        expect {
          post :create, format: :js
        }.to raise_error(
               ActionController::UrlGenerationError, 'No route matches {:action=>"create", :controller=>"spree/admin/relations", :format=>:js}'
             )
      end
    end

    context '#update' do
      it 'redirects to product/related url' do
        params = {
          product_id: product.id,
          id: relation.id,
          relation: { discount_amount: 2.0 }
        }

        put :update, params: params
        expect(response).to redirect_to(spree.admin_product_path(relation.relatable) + '/related')
      end
    end

    context '#destroy' do
      it 'records successfully' do
        params = {
          id: relation.id,
          product_id: relation.relatable_id,
          format: :js
        }

        expect {
          delete :destroy, params: params
        }.to change(Spree::Relation, :count).by(-1)
      end
    end

    context '#update_positions' do
      it 'returns the correct position of the related products' do
        other2    = create(:product)
        relation2 = create(:relation, relatable: product, related_to: other2, relation_type: relation_type, position: 1)
        params = {
          product_id: product.id,
          id: relation.id,
          positions: {
            relation.id => '1',
            relation2.id => '0'
          },
          format: :js
        }

        expect {
          post :update_positions, params: params
          relation.reload
        }.to change(relation, :position).from(0).to(1)
      end
    end
  end
end
