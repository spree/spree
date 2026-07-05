require 'spec_helper'

RSpec.describe Spree::Admin::Orders::ReturnAuthorizationsController do
  stub_authorization!
  render_views

  let(:order) { create(:shipped_order) }
  let(:return_authorization) { create(:return_authorization, order: order) }
  let!(:return_item) { create(:return_item, return_authorization: return_authorization, inventory_unit: order.inventory_units.shipped.first) }
  let!(:reimbursement_type) { create(:reimbursement_type) }

  describe '#new' do
    subject { get :new, params: { order_id: order.to_param } }

    before { subject }

    it 'is successful' do
      expect(response).to be_successful
    end

    it 'loads variables' do
      expect(assigns(:return_authorization)).to be_a_new(Spree::ReturnAuthorization)
      expect(assigns(:form_return_items)).to be_present
      expect(assigns(:reimbursement_types)).to be_present
      expect(assigns(:reasons)).to be_present
    end
  end

  describe '#create' do
    subject do
      post :create, params: {
        order_id: order.to_param,
        return_authorization: {
          memo: 'Test memo',
          return_authorization_reason_id: reason.id,
          stock_location_id: order.shipments.first.stock_location_id,
          return_items_attributes: {
            0 => {
              inventory_unit_id: order.inventory_units.shipped.first.id,
              pre_tax_amount: 10,
              preferred_reimbursement_type_id: reimbursement_type.id
            }
          }
        }
      }
    end

    let(:reason) { create(:return_authorization_reason) }

    it 'creates a new return authorization' do
      expect { subject }.to change(Spree::ReturnAuthorization, :count).by(1)

      return_auth = order.return_authorizations.last
      expect(return_auth.memo).to eq 'Test memo'
      expect(return_auth.return_items.count).to eq 1
      expect(return_auth.return_items.first.pre_tax_amount).to eq 10
      expect(return_auth.return_items.first.preferred_reimbursement_type).to eq reimbursement_type
    end

    it 'redirects to the edit page of the return authorization' do
      subject
      expect(response).to redirect_to(spree.edit_admin_order_path(order))
    end
  end

  describe '#edit' do
    subject { get :edit, params: { order_id: order.to_param, id: return_authorization.to_param } }

    before { subject }

    it 'is successful' do
      expect(response).to be_successful
    end

    it 'loads variables' do
      expect(assigns(:return_authorization)).to eq return_authorization
      expect(assigns(:form_return_items)).to be_present
      expect(assigns(:reimbursement_types)).to be_present
      expect(assigns(:reasons)).to be_present
    end
  end

  describe '#update' do
    subject do
      put :update, params: params
    end

    let(:params) do
      {
        order_id: order.to_param,
        id: return_authorization.to_param,
        return_authorization: {
          memo: 'Updated memo',
          return_items_attributes: {
            0 => {
              id: return_item.id,
              pre_tax_amount: 15
            }
          }
        }
      }
    end

    it 'updates the return authorization' do
      subject

      return_authorization.reload
      expect(return_authorization.memo).to eq 'Updated memo'
      expect(return_authorization.return_items.first.pre_tax_amount).to eq 15
    end

    it 'redirects to the edit page of the return authorization' do
      subject
      expect(response).to redirect_to(spree.edit_admin_order_path(order))
    end

    context 'when _destroy is set to true' do
      let(:params) do
        {
          order_id: order.to_param,
          id: return_authorization.to_param,
          return_authorization: { return_items_attributes: { '0' => { id: return_item.id, _destroy: true } } }
        }
      end

      it 'can destroy return items' do
        subject
        expect(return_authorization.return_items.count).to eq 0
        expect(Spree::ReturnItem.find_by(id: return_item.id)).to be_nil
      end
    end
  end

  describe '#show' do
    subject { get :show, params: { order_id: order.to_param, id: return_authorization.to_param } }

    before { subject }

    it 'is successful' do
      expect(response).to be_successful
    end
  end

  describe '#load_return_authorization_reasons' do
    subject { get :new, params: { order_id: order.to_param } }

    let!(:active_reason) { create(:return_authorization_reason) }
    let!(:inactive_reason) { create(:return_authorization_reason, active: false) }

    it 'loads only active reasons for new RMAs' do
      subject
      expect(assigns(:reasons)).to include(active_reason)
      expect(assigns(:reasons)).not_to include(inactive_reason)
    end

    context 'with an inactive reason already assigned' do
      before do
        return_authorization.update(reason: inactive_reason)
      end

      it 'includes the inactive reason when editing' do
        get :edit, params: { order_id: order.to_param, id: return_authorization.to_param }
        expect(assigns(:reasons)).to include(active_reason)
        expect(assigns(:reasons)).to include(inactive_reason)
      end
    end
  end
end
