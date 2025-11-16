require 'spec_helper'

RSpec.describe Spree::Admin::ReturnAuthorizationsController do
  stub_authorization!
  render_views

  let(:store) { @default_store }
  let(:order) { create(:shipped_order, store: store) }

  let!(:return_authorizations) do
    [
      create(:return_authorization, order: order, created_at: 3.days.ago),
      create(:return_authorization, order: order, created_at: 1.hour.ago),
      create(:return_authorization, order: order, created_at: 10.minutes.ago)
    ]
  end

  describe '#index' do
    subject { get :index }

    it 'is successful' do
      subject
      expect(response).to be_successful
      expect(assigns(:collection)).to contain_exactly(*return_authorizations)
    end

    context 'when there are no return authorizations' do
      let!(:return_authorizations) { [] }

       it 'is successful' do
         subject
         expect(response).to be_successful
         expect(assigns(:collection)).to be_empty
       end
    end
  end

  describe '#cancel' do
    let(:return_authorization) { return_authorizations.first }
    let!(:return_item) { create(:return_item, return_authorization: return_authorization, inventory_unit: order.inventory_units.shipped.first) }

    subject { put :cancel, params: { id: return_authorization.id } }

    it 'cancels the return authorization' do
      expect { subject }.to change { return_authorization.reload.state }.from('authorized').to('canceled')
    end

    it 'sets a flash message' do
      subject
      expect(flash[:success]).to eq Spree.t(:return_authorization_canceled)
    end

    it 'redirects to the order edit page' do
      subject
      expect(response).to redirect_to(spree.edit_admin_order_path(return_authorization.order))
    end
  end

  describe '#destroy' do
    let(:return_authorization) { return_authorizations.first }

    subject { delete :destroy, params: { id: return_authorization.id } }

    it 'destroys the return authorization' do
      expect { subject }.to change(Spree::ReturnAuthorization, :count).by(-1)
    end

    it 'redirects to the order edit page' do
      subject
      expect(response).to redirect_to(spree.edit_admin_order_path(return_authorization.order))
    end
  end
end
