require 'spec_helper'

module Spree
  describe Api::OrdersController do
    render_views

    let!(:order) { create(:order) }
    let(:attributes) { [:number, :item_total, :total,
                        :state, :adjustment_total,
                        :user_id, :created_at, :updated_at,
                        :completed_at, :payment_total, :shipment_state,
                        :payment_state, :email, :special_instructions, :token] }


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
      json_response["adjustments"].should be_empty
      json_response["credit_cards"].should be_empty
    end

    # Regression test for #1992
    it "can view an order not in a standard state" do
      Order.any_instance.stub :user => current_api_user
      order.update_column(:state, 'shipped')
      api_get :show, :id => order.to_param
    end

    it "can not view someone else's order" do
      Order.any_instance.stub :user => stub_model(Spree::LegacyUser)
      api_get :show, :id => order.to_param
      assert_unauthorized!
    end

    it "cannot cancel an order that doesn't belong to them" do
      order.update_attribute(:completed_at, Time.now)
      order.update_attribute(:shipment_state, "ready")
      api_put :cancel, :id => order.to_param
      assert_unauthorized!
    end

    it "cannot add address information to an order that doesn't belong to them" do
      api_put :address, :id => order.to_param
      assert_unauthorized!
    end

    context "create order" do
      let(:current_api_user) do
        user = Spree.user_class.new(:email => "spree@example.com")
        user.generate_spree_api_key!
        user
      end

      it "can create an order" do
        variant = create(:variant)
        api_post :create, :order => { :line_items => { "0" => { :variant_id => variant.to_param, :quantity => 5 } } }
        response.status.should == 201
        order = Order.last
        order.line_items.count.should == 1
        order.line_items.first.variant.should == variant
        order.line_items.first.quantity.should == 5
        json_response["state"].should == "cart"
        order.user.should == current_api_user
        order.email == current_api_user.email
        json_response["user_id"].should == current_api_user.id
      end

      it "cannot create an order with an abitrary price for the line item" do
        variant = create(:variant)
        api_post :create, :order => {
          :line_items => {
            "0" => {
              :variant_id => variant.to_param,
              :quantity => 5,
              :price => 0.44
            }
          }
        }
        response.status.should == 201
        order = Order.last
        order.line_items.count.should == 1
        order.line_items.first.variant.should == variant
        order.line_items.first.quantity.should == 5
        order.line_items.first.price.should == order.line_items.first.variant.price
      end
    end

    it "can create an order without any parameters" do
      lambda { api_post :create }.should_not raise_error
      response.status.should == 201
      order = Order.last
      json_response["state"].should == "cart"
    end

    context "working with an order" do

      let(:variant) { create(:variant) }
      let!(:line_item) { order.contents.add(variant, 1) }
      let!(:payment_method) { create(:payment_method) }

      let(:address_params) { { :country_id => Country.first.id, :state_id => State.first.id } }
      let(:billing_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                                :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                                :country_id => Country.first.id, :state_id => State.first.id} }
      let(:shipping_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                                 :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                                 :country_id => Country.first.id, :state_id => State.first.id} }

      before do
        Order.any_instance.stub :user => current_api_user
        order.next # Switch from cart to address
        order.bill_address = nil
        order.ship_address = nil
        order.save
        order.state.should == "address"
      end

      def clean_address(address)
        address.delete(:state)
        address.delete(:country)
        address
      end

      let(:address_params) { { :country_id => Country.first.id, :state_id => State.first.id } }
      let(:billing_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                                :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                                :country_id => Country.first.id, :state_id => State.first.id} }
      let(:shipping_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                                 :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                                 :country_id => Country.first.id, :state_id => State.first.id} }
      let!(:payment_method) { create(:payment_method) }

      it "updates quantities of existing line items" do
        api_put :update, :id => order.to_param, :order => {
          :line_items => {
            line_item.id => { :quantity => 10 }
          }
        }

        response.status.should == 200
        json_response['line_items'].count.should == 1
        json_response['line_items'].first['quantity'].should == 10
      end

      it "cannot set a price for a line item" do
        variant = create(:variant)
        api_put :update, :id => order.to_param, :order => {
          :line_items_attributes => { order.line_items.first.id =>
            { :variant_id => variant.id, :quantity => 2, :price => 0.44}
          }
        }
        response.status.should == 200
        json_response['line_items'].count.should == 1
        expect(json_response['line_items'].first['price']).to eq(variant.price.to_s)
      end

      it "can add billing address" do
        api_put :update, :id => order.to_param, :order => { :bill_address_attributes => billing_address }

        order.reload.bill_address.should_not be_nil
      end

      it "receives error message if trying to add billing address with errors" do
        billing_address[:firstname] = ""

        api_put :update, :id => order.to_param, :order => { :bill_address_attributes => billing_address }

        json_response['error'].should_not be_nil
        json_response['errors'].should_not be_nil
        json_response['errors']['bill_address.firstname'].first.should eq "can't be blank"
      end

      it "can add shipping address" do
        pending "need to figure out how to get shipping methods for an order"
        order.ship_address.should be_nil

        api_put :update, :id => order.to_param, :order => { :ship_address_attributes => shipping_address }

        order.reload.ship_address.should_not be_nil
      end

      it "receives error message if trying to add shipping address with errors" do
        order.ship_address.should be_nil
        shipping_address[:firstname] = ""

        api_put :update, :id => order.to_param, :order => { :ship_address_attributes => shipping_address }

        json_response['error'].should_not be_nil
        json_response['errors'].should_not be_nil
        json_response['errors']['ship_address.firstname'].first.should eq "can't be blank"
      end

      context "order has shipments" do
        before { order.create_proposed_shipments }

        it "clears out all existing shipments on line item udpate" do
          previous_shipments = order.shipments
          api_put :update, :id => order.to_param, :order => {
            :line_items => {
              line_item.id => { :quantity => 10 }
            }
          }
          expect(order.reload.shipments).to be_empty
        end
      end

      context "with a line item" do
        before do
          create(:line_item, :order => order)
          order.reload
        end

        it "can empty an order" do
          api_put :empty, :id => order.to_param
          response.status.should == 200
          order.reload.line_items.should be_empty
        end

        it "can list its line items with images" do
          order.line_items.first.variant.images.create!(:attachment => image("thinking-cat.jpg"))

          api_get :show, :id => order.to_param

          json_response['line_items'].first['variant'].should have_attributes([:images])
        end

        it "lists variants product id" do
          api_get :show, :id => order.to_param

          json_response['line_items'].first['variant'].should have_attributes([:product_id])
        end
      end
    end

    context "as an admin" do
      sign_in_as_admin!

      context "with no orders" do
        before { Spree::Order.delete_all }
        it "still returns a root :orders key" do
          api_get :index
          json_response["orders"].should == []
        end
      end

      context "with two orders" do
        before { create(:order) }

        it "can view all orders" do
          api_get :index
          json_response["orders"].first.should have_attributes(attributes)
          json_response["count"].should == 2
          json_response["current_page"].should == 1
          json_response["pages"].should == 1
        end

        # Test for #1763
        it "can control the page size through a parameter" do
          api_get :index, :per_page => 1
          json_response["orders"].count.should == 1
          json_response["orders"].first.should have_attributes(attributes)
          json_response["count"].should == 1
          json_response["current_page"].should == 1
          json_response["pages"].should == 2
        end
      end

      context "search" do
        before do
          create(:order)
          Spree::Order.last.update_attribute(:email, 'spree@spreecommerce.com')
        end

        let(:expected_result) { Spree::Order.last }

        it "can query the results through a parameter" do
          api_get :index, :q => { :email_cont => 'spree' }
          json_response["orders"].count.should == 1
          json_response["orders"].first.should have_attributes(attributes)
          json_response["orders"].first["email"].should == expected_result.email
          json_response["count"].should == 1
          json_response["current_page"].should == 1
          json_response["pages"].should == 1
        end
      end

      context "can cancel an order" do
        before do
          Spree::Config[:mails_from] = "spree@example.com"

          order.completed_at = Time.now
          order.state = 'complete'
          order.shipment_state = 'ready'
          order.save!
        end

        specify do
          api_put :cancel, :id => order.to_param
          json_response["state"].should == "canceled"
        end
      end
    end
  end
end
