require 'spec_helper'

module Spree
  module Admin
    describe PaymentsController do
      stub_authorization!

      let(:order) { create(:order) }

      before do
        Spree::Order.stub find_by_number!: order
        order.stub(:payment_required? => true)
      end

      context "order has no payments" do
        context "passed through customer details step" do
          before { order.stub(state: "payment") }

          it "redirect to new payments page" do
            spree_get :index, { amount: 100 }
            response.should redirect_to(spree.new_admin_order_payment_path(order))
          end
        end

        context "try to skip customer details step" do
          it "redirect to customer details step" do
            spree_get :index, { amount: 100 }
            response.should redirect_to(spree.edit_admin_order_customer_path(order))
          end
        end
      end
    end
  end
end
