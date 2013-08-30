require 'spec_helper'
require 'spree/promo/coupon_applicator'

module Spree
  describe Api::CheckoutsController do
    render_views

    before(:each) do
      stub_authentication!
      Spree::Config[:track_inventory_levels] = false
      country_zone = create(:zone, :name => 'CountryZone')
      @state = create(:state)
      @country = @state.country
      country_zone.members.create(:zoneable => @country)
      create(:stock_location)

      @shipping_method = create(:shipping_method, :zones => [country_zone])
      @payment_method = create(:bogus_payment_method)
    end

    after do
      Spree::Config[:track_inventory_levels] = true
    end

    context "POST 'create'" do
      it "creates a new order when no parameters are passed" do
        api_post :create

        json_response['number'].should be_present
        response.status.should == 201
      end
    end

    context "PUT 'update'" do
      let(:order) { create(:order_with_line_items) }

      before(:each) do
        Order.any_instance.stub(:confirmation_required? => true)
        Order.any_instance.stub(:payment_required? => true)
      end

      it "cannot update without a token" do
        api_put :update, :id => order.to_param
        assert_unauthorized!
      end

      it "will return an error if the recently created order cannot transition from cart to address" do
        order.state.should eq "cart"
        order.update_column(:email, nil) # email is necessary to transition from cart to address

        api_put :update, :id => order.to_param, :order_token => order.token

        # Order has not transitioned
        json_response['state'].should == 'cart'
      end

      it "should transition a recently created order from cart to address" do
        order.state.should eq "cart"
        order.email.should_not be_nil
        api_put :update, :id => order.to_param, :order_token => order.token
        order.reload.state.should eq "address"
      end

      it "can take line_items_attributes as a parameter" do
        line_item = order.line_items.first
        api_put :update, :id => order.to_param, :order_token => order.token,
                         :order => { :line_items_attributes => { line_item.id => { :quantity => 1 } } }
        response.status.should == 200
      end

      it "can take line_items as a parameter" do
        line_item = order.line_items.first
        api_put :update, :id => order.to_param, :order_token => order.token,
                         :order => { :line_items => { line_item.id => { :quantity => 1 } } }
        response.status.should == 200
      end

      it "will return an error if the order cannot transition" do
        order.bill_address = nil
        order.save
        order.update_column(:state, "address")
        api_put :update, :id => order.to_param, :order_token => order.token
        response.status.should == 422
      end

      it "can update addresses and transition from address to delivery" do
        order.update_column(:state, "address")
        shipping_address = billing_address = {
          :firstname  => 'John',
          :lastname   => 'Doe',
          :address1   => '7735 Old Georgetown Road',
          :city       => 'Bethesda',
          :phone      => '3014445002',
          :zipcode    => '20814',
          :state_id   => @state.id,
          :country_id => @country.id
        }
        api_put :update,
                :id => order.to_param, :order_token => order.token,
                :order => { :bill_address_attributes => billing_address, :ship_address_attributes => shipping_address }
        json_response['state'].should == 'delivery'
        json_response['bill_address']['firstname'].should == 'John'
        json_response['ship_address']['firstname'].should == 'John'
        response.status.should == 200
      end

      it "can update shipping method and transition from delivery to payment" do
        order.update_column(:state, "delivery")
        shipment = create(:shipment, :order => order)
        shipping_rate = shipment.shipping_rates.first
        api_put :update, :id => order.to_param, :order_token => order.token, :order => { :shipments_attributes => { "0" => { :selected_shipping_rate_id => shipping_rate.id, :id => shipment.id } } }
        json_response['shipments'][0]['shipping_method']['name'].should == @shipping_method.name
        json_response['state'].should == 'payment'
        response.status.should == 200
      end

      it "can update payment method and transition from payment to confirm" do
        order.update_column(:state, "payment")
        api_put :update, :id => order.to_param, :order_token => order.token, :order => { :payments_attributes => [{ :payment_method_id => @payment_method.id }] }
        json_response['state'].should == 'confirm'
        json_response['payments'][0]['payment_method']['name'].should == @payment_method.name
        response.status.should == 200
      end

      it "can update payment method with source and transition from payment to confirm" do
        order.update_column(:state, "payment")
        source_attributes = {
          "number" => "4111111111111111",
          "month" => 1.month.from_now.month,
          "year" => 1.month.from_now.year,
          "verification_value" => "123"
        }

        api_put :update, :id => order.to_param, :order_token => order.token,
          :order => { :payments_attributes => [{ :payment_method_id => @payment_method.id.to_s }],
                      :payment_source => { @payment_method.id.to_s => source_attributes } }
        json_response['payments'][0]['payment_method']['name'].should == @payment_method.name
        json_response['payments'][0]['amount'].should == order.total.to_s
        response.status.should == 200
      end

      it "returns errors when source is missing attributes" do
        order.update_column(:state, "payment")
        api_put :update, :id => order.to_param, :order_token => order.token,
          :order => { :payments_attributes => [{ :payment_method_id => @payment_method.id.to_s }],
                      :payment_source => { @payment_method.id.to_s => { } } }
        response.status.should == 422
        cc_errors = json_response['errors']['payments.Credit Card']
        cc_errors.should include("Number can't be blank")
        cc_errors.should include("Month is not a number")
        cc_errors.should include("Year is not a number")
        cc_errors.should include("Verification Value can't be blank")
      end

      it "can transition from confirm to complete" do
        order.update_column(:state, "confirm")
        Spree::Order.any_instance.stub(:payment_required? => false)
        api_put :update, :id => order.to_param, :order_token => order.token
        json_response['state'].should == 'complete'
        response.status.should == 200
      end

      it "returns the order if the order is already complete" do
        order.update_column(:state, "complete")
        api_put :update, :id => order.to_param, :order_token => order.token
        json_response['number'].should == order.number
        response.status.should == 200
      end

      context "as an admin" do
        sign_in_as_admin!
        it "can assign a user to the order" do
          user = create(:user)
          # Need to pass email as well so that validations succeed
          api_put :update, :id => order.to_param, :order => { :user_id => user.id, :email => "guest@spreecommerce.com" }
          response.status.should == 200
          json_response['user_id'].should == user.id
        end
      end

      it "can assign an email to the order" do
        api_put :update, :id => order.to_param, :order => { :email => "guest@spreecommerce.com" }, :order_token => order.token
        json_response['email'].should == "guest@spreecommerce.com"
        response.status.should == 200
      end

      it "can apply a coupon code to an order" do
        order.update_column(:state, "payment")
        Spree::Promo::CouponApplicator.should_receive(:new).with(order).and_call_original
        Spree::Promo::CouponApplicator.any_instance.should_receive(:apply).and_return({:coupon_applied? => true})
        api_put :update, :id => order.to_param, :order => { :coupon_code => "foobar" }, :order_token => order.token
      end

      it "can apply a coupon code to an order" do
        order.update_column(:state, "payment")
        Spree::Promo::CouponApplicator.should_receive(:new).with(order).and_call_original
        coupon_result = { :coupon_applied? => true }
        Spree::Promo::CouponApplicator.any_instance.should_receive(:apply).and_return(coupon_result)
        api_put :update, :id => order.to_param, :order_token => order.token, :order => { :coupon_code => "foobar" }
      end
    end

    context "PUT 'next'" do
      let!(:order) { create(:order_with_line_items) }
      it "cannot transition to address without a line item" do
        order.line_items.delete_all
        order.update_column(:email, "spree@example.com")
        api_put :next, :id => order.to_param, :order_token => order.token
        response.status.should == 422
        json_response["errors"]["base"].should include(Spree.t(:there_are_no_items_for_this_order))
      end

      it "can transition an order to the next state" do
        order.update_column(:email, "spree@example.com")

        api_put :next, :id => order.to_param, :order_token => order.token
        response.status.should == 200
        json_response['state'].should == 'address'
      end

      it "cannot transition if order email is blank" do
        order.update_column(:email, nil)

        api_put :next, :id => order.to_param, :order_token => order.token
        response.status.should == 422
        json_response['error'].should =~ /could not be transitioned/
      end

      it "returns a sensible error when no payment method is specified" do
        order.update_column(:state, "payment")
        api_put :next, :id => order.to_param, :order_token => order.token, :order => {}
        json_response["errors"]["base"].should include(Spree.t(:no_pending_payments))
      end
    end

    context "PUT 'advance'" do
      let!(:order) { create(:order_with_line_items) }
      it 'continues to advance advances an order while it can move forward' do
        Spree::Order.any_instance.should_receive(:next).exactly(3).times.and_return(true, true, false)
        api_put :advance, :id => order.to_param, :order_token => order.token
      end
      it 'returns the order' do
        api_put :advance, :id => order.to_param, :order_token => order.token
        json_response['id'].should == order.id
      end

    end
  end
end
