require 'spec_helper'

RSpec.describe Spree::Admin::CustomerGroupsController, type: :controller do
  stub_authorization!
  render_views

  let(:store) { @default_store }

  describe 'GET #index' do
    subject(:index) { get :index }

    let!(:customer_group) { create(:customer_group, store: store) }

    it 'renders the list of customer groups' do
      index

      expect(response).to render_template(:index)
      expect(assigns[:collection]).to include(customer_group)
    end
  end

  describe 'GET #new' do
    subject(:new) { get :new }

    it 'renders the new customer group page' do
      new
      expect(response).to render_template(:new)
    end
  end

  describe 'POST #create' do
    subject(:create_customer_group) { post :create, params: { customer_group: customer_group_params } }

    let(:customer_group_params) do
      {
        name: 'VIP Customers',
        description: 'Our most valued customers'
      }
    end

    it 'creates a new customer group' do
      expect { create_customer_group }.to change(Spree::CustomerGroup, :count).by(1)

      customer_group = Spree::CustomerGroup.last
      expect(customer_group.name).to eq('VIP Customers')
      expect(customer_group.description).to eq('Our most valued customers')
      expect(customer_group.store).to eq(store)
    end

    it 'redirects to the new customer group page' do
      create_customer_group
      expect(response).to redirect_to(spree.admin_customer_group_path(Spree::CustomerGroup.last))
    end
  end

  describe 'GET #show' do
    subject(:show) { get :show, params: { id: customer_group.id } }

    let(:customer_group) { create(:customer_group, store: store) }

    it 'renders the show page' do
      show
      expect(response).to render_template(:show)
      expect(assigns[:customer_group]).to eq(customer_group)
    end
  end

  describe 'GET #edit' do
    subject(:edit) { get :edit, params: { id: customer_group.id } }

    let(:customer_group) { create(:customer_group, store: store) }

    it 'renders the edit page' do
      edit
      expect(response).to render_template(:edit)
    end
  end

  describe 'PUT #update' do
    let!(:customer_group) { create(:customer_group, store: store) }
    let(:customer_group_params) do
      {
        name: 'Premium Customers',
        description: 'Updated description'
      }
    end

    it 'updates the customer group' do
      put :update, params: { id: customer_group.id, customer_group: customer_group_params }
      customer_group.reload

      expect(customer_group.name).to eq('Premium Customers')
      expect(customer_group.description).to eq('Updated description')
    end

    context 'with turbo_stream format' do
      subject(:update_turbo) { put :update, params: { id: customer_group.id, customer_group: customer_group_params }, format: :turbo_stream }

      it 'returns turbo_stream response' do
        update_turbo
        expect(response.media_type).to eq('text/vnd.turbo-stream.html')
      end

      it 'updates the customer group' do
        update_turbo
        customer_group.reload

        expect(customer_group.name).to eq('Premium Customers')
      end

      context 'with invalid params' do
        let(:customer_group_params) { { name: '' } }

        it 'renders the edit form in drawer' do
          update_turbo
          expect(response.body).to include('drawer')
        end
      end
    end
  end

  describe 'DELETE #destroy' do
    subject(:destroy_customer_group) { delete :destroy, params: { id: customer_group.id } }

    let!(:customer_group) { create(:customer_group, store: store) }

    it 'destroys the customer group' do
      expect { destroy_customer_group }.to change(Spree::CustomerGroup, :count).by(-1)
    end
  end

  describe 'GET #select_options' do
    subject(:select_options) { get :select_options, params: { q: 'VIP' }, format: :json }

    let!(:vip_group) { create(:customer_group, name: 'VIP', store: store) }
    let!(:other_group) { create(:customer_group, name: 'Regular', store: store) }

    it 'returns matching customer groups as JSON' do
      select_options

      json_response = JSON.parse(response.body)
      expect(json_response.length).to eq(1)
      expect(json_response.first['name']).to eq('VIP')
    end
  end
end
