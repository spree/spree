require 'spec_helper'

module Spree
  describe Api::V1::ReturnAuthorizationsController, type: :controller do
    render_views

    let!(:order) { create(:shipped_order) }

    let(:product) { create(:product) }
    let(:attributes) { [:id, :memo, :state] }
    let(:resource_scoping) { { order_id: order.to_param } }

    before do
      stub_authentication!
    end

    context 'as the order owner' do
      before do
        allow_any_instance_of(Order).to receive_messages user: current_api_user
      end

      it 'cannot see any return authorizations' do
        api_get :index
        assert_unauthorized!
      end

      it 'cannot see a single return authorization' do
        api_get :show, id: 1
        assert_unauthorized!
      end

      it 'cannot learn how to create a new return authorization' do
        api_get :new
        assert_unauthorized!
      end

      it 'cannot create a new return authorization' do
        api_post :create
        assert_unauthorized!
      end

      it 'cannot update a return authorization' do
        api_put :update, id: 1
        assert_not_found!
      end

      it 'cannot delete a return authorization' do
        api_delete :destroy, id: 1
        assert_not_found!
      end
    end

    context 'as an admin' do
      sign_in_as_admin!

      it 'can show return authorization' do
        FactoryBot.create(:return_authorization, order: order)
        return_authorization = order.return_authorizations.first
        api_get :show, order_id: order.number, id: return_authorization.id
        expect(response.status).to eq(200)
        expect(json_response).to have_attributes(attributes)
        expect(json_response['state']).not_to be_blank
      end

      it 'can get a list of return authorizations' do
        FactoryBot.create(:return_authorization, order: order)
        FactoryBot.create(:return_authorization, order: order)
        api_get :index, order_id: order.number
        expect(response.status).to eq(200)
        return_authorizations = json_response['return_authorizations']
        expect(return_authorizations.first).to have_attributes(attributes)
        expect(return_authorizations.first).not_to eq(return_authorizations.last)
      end

      it 'can control the page size through a parameter' do
        FactoryBot.create(:return_authorization, order: order)
        FactoryBot.create(:return_authorization, order: order)
        api_get :index, order_id: order.number, per_page: 1
        expect(json_response['count']).to eq(1)
        expect(json_response['current_page']).to eq(1)
        expect(json_response['pages']).to eq(2)
      end

      it 'can query the results through a paramter' do
        FactoryBot.create(:return_authorization, order: order)
        expected_result = create(:return_authorization, memo: 'damaged')
        order.return_authorizations << expected_result
        api_get :index, q: { memo_cont: 'damaged' }
        expect(json_response['count']).to eq(1)
        expect(json_response['return_authorizations'].first['memo']).to eq expected_result.memo
      end

      it 'can learn how to create a new return authorization' do
        api_get :new
        expect(json_response['attributes']).to eq(['id', 'number', 'state', 'order_id', 'memo', 'created_at', 'updated_at'])
        required_attributes = json_response['required_attributes']
        expect(required_attributes).to include('order')
      end

      it 'can update a return authorization on the order' do
        FactoryBot.create(:return_authorization, order: order)
        return_authorization = order.return_authorizations.first
        api_put :update, id: return_authorization.id, return_authorization: { memo: 'ABC' }
        expect(response.status).to eq(200)
        expect(json_response).to have_attributes(attributes)
      end

      it 'can cancel a return authorization on the order' do
        FactoryBot.create(:new_return_authorization, order: order)
        return_authorization = order.return_authorizations.first
        expect(return_authorization.state).to eq('authorized')
        api_delete :cancel, id: return_authorization.id
        expect(response.status).to eq(200)
        expect(return_authorization.reload.state).to eq('canceled')
      end

      it 'can delete a return authorization on the order' do
        FactoryBot.create(:return_authorization, order: order)
        return_authorization = order.return_authorizations.first
        api_delete :destroy, id: return_authorization.id
        expect(response.status).to eq(204)
        expect { return_authorization.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      it 'can add a new return authorization to an existing order' do
        stock_location = FactoryBot.create(:stock_location)
        reason = FactoryBot.create(:return_authorization_reason)
        rma_params = { stock_location_id: stock_location.id,
                       return_authorization_reason_id: reason.id,
                       memo: 'Defective' }
        api_post :create, order_id: order.number, return_authorization: rma_params
        expect(response.status).to eq(201)
        expect(json_response).to have_attributes(attributes)
        expect(json_response['state']).not_to be_blank
      end
    end

    context 'as just another user' do
      it 'cannot add a return authorization to the order' do
        api_post :create, return_autorization: { order_id: order.number, memo: 'Defective' }
        assert_unauthorized!
      end

      it 'cannot update a return authorization on the order' do
        FactoryBot.create(:return_authorization, order: order)
        return_authorization = order.return_authorizations.first
        api_put :update, id: return_authorization.id, return_authorization: { memo: 'ABC' }
        assert_unauthorized!
        expect(return_authorization.reload.memo).not_to eq('ABC')
      end

      it 'cannot delete a return authorization on the order' do
        FactoryBot.create(:return_authorization, order: order)
        return_authorization = order.return_authorizations.first
        api_delete :destroy, id: return_authorization.id
        assert_unauthorized!
        expect { return_authorization.reload }.not_to raise_error
      end
    end
  end
end
