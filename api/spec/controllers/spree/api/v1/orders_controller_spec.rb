require 'spec_helper'

module Spree
  describe Api::V1::OrdersController do
    render_views

    let!(:order) { create(:order) }
    let(:attributes) { [:number, :item_total, :total,
                        :state, :adjustment_total,
                        :user_id, :created_at, :updated_at,
                        :completed_at, :payment_total, :shipment_state,
                        :payment_state, :email, :special_instructions] }


    before do
      stub_authentication!
    end

    it "cannot view all orders" do
      api_get :index
      assert_unauthorized!
    end

    it "can view their own order" do
      Order.any_instance.stub :user => current_api_user
      api_get :show, :id => order.to_param
      response.status.should == 200
      json_response.should have_attributes(attributes)
    end

    it "can not view someone else's order" do
      Order.any_instance.stub :user => stub_model(User)
      api_get :show, :id => order.to_param
      assert_unauthorized!
    end

    it "cannot cancel an order that doesn't belong to them" do
      order.update_attribute(:completed_at, Time.now)
      order.update_attribute(:shipment_state, "ready")
      api_put :cancel, :id => order.to_param
      assert_unauthorized!
    end

    it "can create an order" do
      variant = create(:variant)
      api_post :create, :order => { :line_items => [{ :variant_id => variant.to_param, :quantity => 5 }] }
      response.status.should == 200
      order = Order.last
      order.line_items.count.should == 1
      order.line_items.first.variant.should == variant
      order.line_items.first.quantity.should == 5
      json_response["order"]["state"].should == "address"
    end

    context "working with an order" do
      before do
        Order.any_instance.stub :user => current_api_user
        create(:payment_method)
        order.next # Switch from cart to address
        order.ship_address.should be_nil
        order.state.should == "address"
      end

      def clean_address(address)
        address.delete(:state)
        address.delete(:country)
        address
      end

      let(:address_params) { { :country_id => Country.first.id, :state_id => State.first.id } }
      let(:shipping_address) { clean_address(attributes_for(:address).merge!(address_params)) }
      let(:billing_address) { clean_address(attributes_for(:address).merge!(address_params)) }
      let!(:shipping_method) { create(:shipping_method) }
      let!(:payment_method) { create(:payment_method) }

      it "can add address information to an order" do
        api_put :address, :id => order.to_param, :shipping_address => shipping_address, :billing_address => billing_address

        response.status.should == 200
        order.reload
        order.shipping_address.reload
        order.billing_address.reload
        # We can assume the rest of the parameters are set if these two are
        order.shipping_address.firstname.should == shipping_address[:firstname]
        order.billing_address.firstname.should == billing_address[:firstname]
        order.state.should == "delivery"
        json_response["order"]["shipping_methods"].should_not be_empty
      end

      it "cannot use an address that has no valid shipping methods" do
        shipping_method.destroy
        api_put :address, :id => order.to_param, :shipping_address => shipping_address, :billing_address => billing_address
        response.status.should == 422
        json_response["errors"]["base"].should == ["No shipping methods available for selected location, please change your address and try again."]
      end

      it "can not add invalid ship address information to an order" do
        shipping_address[:firstname] = ""
        api_put :address, :id => order.to_param, :shipping_address => shipping_address, :billing_address => billing_address

        response.status.should == 422
        json_response["errors"]["ship_address.firstname"].should_not be_blank
      end

      it "can not add invalid ship address information to an order" do
        billing_address[:firstname] = ""
        api_put :address, :id => order.to_param, :shipping_address => shipping_address, :billing_address => billing_address

        response.status.should == 422
        json_response["errors"]["bill_address.firstname"].should_not be_blank
      end

      context "with a line item" do
        before do
          order.line_items << create(:line_item)
        end

        context "for delivery" do
          before do
            order.update_attribute(:state, "delivery")
          end

          it "can select a shipping method for an order" do
            order.shipping_method.should be_nil
            api_put :delivery, :id => order.to_param, :shipping_method_id => shipping_method.id
            response.status.should == 200
            order.reload
            order.state.should == "payment"
            order.shipping_method.should == shipping_method
          end

          it "cannot select an invalid shipping method for an order" do
            order.shipping_method.should be_nil
            api_put :delivery, :id => order.to_param, :shipping_method_id => '1234567890'
            response.status.should == 422
            json_response["errors"].should include("Invalid shipping method specified.")
          end
        end

        it "can empty an order" do
          api_put :empty, :id => order.to_param
          response.status.should == 200
          order.reload.line_items.should be_empty
        end
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      it "can view all orders" do
        api_get :index
        json_response["orders"].first.should have_attributes(attributes)
        json_response["count"].should == 1
        json_response["current_page"].should == 1
        json_response["pages"].should == 1
      end

      context "can cancel an order" do
        before do
          order.completed_at = Time.now
          order.state = 'complete'
          order.shipment_state = 'ready'
          order.save!
        end

        specify do
          api_put :cancel, :id => order.to_param
          json_response["order"]["state"].should == "canceled"
        end
      end
    end
  end
end
