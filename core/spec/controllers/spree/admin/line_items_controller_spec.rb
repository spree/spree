require 'spec_helper'

module Spree
  module Admin
    describe LineItemsController do
      stub_authorization!

      let!(:line_item) { create(:line_item) }
      let!(:order) { line_item.order }

      before { order.update_column :total, 10 }

      context "destroy line item" do
        it "reloads order total" do
          spree_delete :destroy, { :format => :js, :order_id => order.number, :id => line_item.id }
          expect(assigns(:order).total).to eql(order.reload.total)
        end
      end
    end
  end
end
