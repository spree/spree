require 'spec_helper'

module Spree
  module Admin
    describe CustomerReturnsController do
      stub_authorization!

      let(:order)           { customer_return.order }
      let(:customer_return) { create(:customer_return_with_return_items) }

      describe "#index" do
        subject do
          spree_get :index, { order_id: customer_return.order.to_param }
        end

        before { subject }

        it "loads the order" do
          expect(assigns(:order)).to eq order
        end

        it "loads the customer return" do
          expect(assigns(:customer_returns)).to include(customer_return)
        end
      end

      describe "#new" do
        subject do
          spree_get :new, { order_id: customer_return.order.to_param }
        end

        it "loads the order" do
          subject
          expect(assigns(:order)).to eq customer_return.order
        end

        it "creates a new customer return" do
          subject
          expect(assigns(:customer_return)).to_not be_persisted
        end

        context "order does not have unreturned rma items" do
          before { subject }

          it "loads the possible return items" do
            total_unit_count = order.inventory_units.count
            customer_returned_count =  customer_return.return_items.count
            expect(assigns(:new_return_items).length).to eq (total_unit_count - customer_returned_count)
          end

          it "creates new return items" do
            expect(assigns(:new_return_items).all? { |return_item| !return_item.persisted? }).to eq true
          end

          it "does not have any rma return items" do
            expect(assigns(:rma_return_items)).to eq []
          end
        end

        context "order has unreturned rma items" do
          let(:unreturned_rma_item) { customer_return.return_items.last }

          before do
            unreturned_rma_item.update_attributes(customer_return_id: nil)
            subject
          end

          it "loads the possible return items" do
            rma_return_item_count = 1
            total_unit_count = order.inventory_units.count
            customer_returned_count =  customer_return.return_items.count
            expected_total = total_unit_count - customer_returned_count - rma_return_item_count
            expect(assigns(:new_return_items).length).to eq expected_total
          end

          it "creates new return items" do
            expect(assigns(:new_return_items).all? { |return_item| !return_item.persisted? }).to eq true
          end

          it "loads the persisted rma return items" do
            expect(assigns(:rma_return_items).all? { |return_item| return_item.persisted? }).to eq true
          end

          it "has one rma return item" do
            expect(assigns(:rma_return_items)).to include(unreturned_rma_item)
          end
        end
      end

      describe "#create" do
        subject do
          spree_post :create, customer_return_params
        end

        context "valid customer return" do
          let(:stock_location) { order.shipments.last.stock_location }

          let!(:customer_return_params) do
            {
              order_id: customer_return.order.to_param,
              customer_return: {
                stock_location_id: stock_location.id,
                return_items_attributes: {
                  "0" => {
                    returned: "1",
                    "pre_tax_amount"=>"15.99",
                    inventory_unit_id: order.inventory_units.shipped.last.id
                  }
                }
              }
            }
          end

          it "creates a customer return" do
            expect{ subject }.to change { Spree::CustomerReturn.count }.by(1)
          end

          it "redirects to the index page" do
            subject
            expect(response).to redirect_to(spree.admin_order_customer_returns_path(order))
          end
        end

        context "invalid customer return" do
          let!(:customer_return_params) do
            {
              order_id: customer_return.order.to_param,
              customer_return: {
                stock_location_id: "",
                return_items_attributes: {
                  "0" => {
                    returned: "1",
                    "pre_tax_amount"=>"15.99",
                    inventory_unit_id: order.inventory_units.shipped.last.id
                  }
                }
              }
            }
          end

          it "doesn't create a customer return" do
            expect{ subject }.to_not change { Spree::CustomerReturn.count }
          end

          it "renders the new page" do
            subject
            expect(response).to render_template(:new)
          end
        end
      end

      describe "#refund" do
        let(:customer_return_id) { customer_return.to_param }

        subject do
          spree_put :refund, { order_id: order.to_param, id: customer_return_id }
        end

        before do
          Spree::CustomerReturn.should_receive(:find).with(customer_return_id) { customer_return }
        end

        context "refund is successful" do
          before do
            customer_return.stub(refund: true)
          end

          it "redirects to the index page" do
            subject
            expect(response).to redirect_to(spree.admin_order_customer_returns_path(order))
          end

          it "adds a success message to the flash" do
            subject
            expect(flash[:success]).to_not be_nil
          end
        end

        context "refund is not successful" do
          before do
            customer_return.stub(refund: false)
          end

          it "redirects to the index page" do
            subject
            expect(response).to redirect_to(spree.admin_order_customer_returns_path(order))
          end

          it "adds an error message to the flash" do
            subject
            expect(flash[:error]).to_not be_nil
          end
        end
      end
    end
  end
end
