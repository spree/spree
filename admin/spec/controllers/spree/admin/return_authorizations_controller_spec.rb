require 'spec_helper'

RSpec.describe Spree::Admin::ReturnAuthorizationsController do
  stub_authorization!
  render_views

  let(:order) { create(:shipped_order) }
  let(:return_authorization) { create(:return_authorization, order: order) }
  let!(:return_item) { create(:return_item, return_authorization: return_authorization, inventory_unit: order.inventory_units.shipped.first) }

  describe '#index' do
    subject { get :index }

    it 'is successful' do
      subject
      expect(response).to be_successful
    end

    context 'when there are no return authorizations' do
      before { Spree::ReturnAuthorization.destroy_all }

       it 'is successful' do
         subject
         expect(response).to be_successful
       end
    end
  end

  describe '#cancel' do
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
    subject { delete :destroy, params: { id: return_authorization.id } }

    it 'destroys the return authorization' do
      expect { subject }.to change(Spree::ReturnAuthorization, :count).by(-1)
    end

    it 'redirects to the order edit page' do
      subject
      expect(response).to redirect_to(spree.edit_admin_order_path(return_authorization.order))
    end
  end

  describe '#collection' do
    let!(:return_authorizations) { create_list(:return_authorization, 3) }

    before do
      # Create one for a different store to test store filtering
      other_store = create(:store)
      create(:return_authorization, order: create(:shipped_order, store: other_store))
    end

    it 'returns return authorizations for the current store' do
      # Call the private method directly
      collection = controller.send(:collection)

      expect(collection.count).to eq 4 # 3 created above + 1 from let
      expect(collection.all? { |ra| ra.order.store == Spree::Store.default }).to be true
    end

    it 'orders by created_at desc' do
      # Call the private method directly
      collection = controller.send(:collection)

      expect(collection).to eq [*return_authorizations.reverse, return_authorization]
    end

    it 'paginates the results' do
      allow(controller).to receive(:params).and_return({ per_page: '2', page: '1' })

      # Call the private method directly
      collection = controller.send(:collection)

      expect(collection.limit_value).to eq 2
      expect(collection.current_page).to eq 1
    end
  end
end
