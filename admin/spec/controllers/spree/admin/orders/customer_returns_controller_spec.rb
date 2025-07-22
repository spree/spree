require 'spec_helper'

RSpec.describe Spree::Admin::Orders::CustomerReturnsController do
  stub_authorization!
  render_views

  let(:order) { create(:shipped_order) }
  let(:return_authorization) { create(:return_authorization, order: order) }
  let!(:return_item) { create(:return_item, return_authorization: return_authorization, inventory_unit: order.inventory_units.shipped.first) }

  describe '#new' do
    subject { get :new, params: { order_id: order.number } }

    before { subject }

    it 'is successful' do
      expect(response).to be_successful
    end

    it 'loads variables' do
      expect(assigns(:rma_return_items)).to eq [return_item]
    end
  end

  describe '#create' do
    subject do
      post :create, params: {
        order_id: order.number,
        customer_return: {
          stock_location_id: order.shipments.first.stock_location.id,
          return_items_attributes: {
            1 => {
              id: return_item.id,
              returned: 1,
              pre_tax_amount: 10,
              resellable: 1
            }
          }
        }
      }
    end

    it 'creates a new customer return' do
      subject

      expect(order.customer_returns.count).to eq 1

      customer_return = order.customer_returns.first
      expect(customer_return.return_items.count).to eq 1
      expect(customer_return.return_items.first.pre_tax_amount).to eq 10
      expect(customer_return.return_items.first.resellable).to eq true
    end

    it 'redirects to order edit page' do
      subject

      expect(response).to redirect_to(edit_admin_order_path(order))
    end
  end

  describe '#edit' do
    subject { get :edit, params: { order_id: order.number, id: customer_return.id } }

    let(:customer_return) { create(:customer_return_without_return_items, return_items: [return_item]) }

    before { subject }

    it 'is successful' do
      expect(response).to be_successful
    end

    it 'loads variables' do
      expect(assigns(:rma_return_items)).to eq []
      expect(assigns(:pending_return_items)).to eq []
      expect(assigns(:accepted_return_items)).to eq [return_item]
      expect(assigns(:rejected_return_items)).to eq []
      expect(assigns(:manual_intervention_return_items)).to eq []
      expect(assigns(:pending_reimbursements)).to eq []
    end
  end

  describe '#update' do
    subject do
      put :update, params: {
        order_id: order.number,
        id: customer_return.id,
        customer_return: {
          return_items_attributes: {
            1 => {
              id: return_item.id,
              pre_tax_amount: 12
            }
          }
        }
      }
    end

    let(:customer_return) { create(:customer_return_without_return_items, return_items: [return_item]) }

    it 'updates the return item' do
      subject

      return_item.reload
      expect(return_item.pre_tax_amount).to eq 12
    end
  end
end
