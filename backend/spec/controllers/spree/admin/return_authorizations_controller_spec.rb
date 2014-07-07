require 'spec_helper'

describe Spree::Admin::ReturnAuthorizationsController do
  stub_authorization!

  # Regression test for #1370 #3
  let!(:order) { create(:shipped_order, line_items_count: 3) }
  let(:inventory_unit_1) { order.inventory_units.order('id asc')[0] }
  let(:inventory_unit_2) { order.inventory_units.order('id asc')[1] }
  let(:inventory_unit_3) { order.inventory_units.order('id asc')[2] }

  let(:params) do
    {
      order_id: order.to_param,
      return_authorization: {reason: ""},
    }
  end

  it "can create a return authorization" do
    spree_post :create, params
    response.should redirect_to spree.admin_order_return_authorizations_path(order)
  end

  context 'update' do
    let(:return_authorization) { create(:return_authorization, order: order) }
    let(:params) do
      super().merge({
        id: return_authorization.to_param,
        return_authorization: {reason: ""}.merge(return_items_params),
      })
    end

    subject { spree_put :update, params }

    context "adding an item" do
      let(:return_items_params) do
        {
          return_items_attributes: {
            '0' => {inventory_unit_id: inventory_unit_1.to_param},
          }
        }
      end

      context 'without existing items' do
        it 'creates a new item' do
          expect { subject }.to change { Spree::ReturnItem.count }.by(1)
        end
      end

      context 'with existing items' do
        let!(:return_item) {
          create(:return_item, return_authorization: return_authorization, inventory_unit: inventory_unit_1)
        }

        it 'does not create new items' do
          expect { subject }.to_not change { Spree::ReturnItem.count }
          expect(assigns[:return_authorization].errors['return_items.inventory_unit']).to eq ["has already been taken"]
        end
      end
    end

    context "removing an item" do
      let!(:return_item) {
        create(:return_item, return_authorization: return_authorization, inventory_unit: inventory_unit_1)
      }

      let(:return_items_params) do
        {
          return_items_attributes: {
            '0' => {id: return_item.to_param, _destroy: '1'},
          }
        }
      end

      context 'with existing items' do
        it 'removes the item' do
          expect { subject }.to change { Spree::ReturnItem.count }.by(-1)
        end
      end
    end
  end
end
