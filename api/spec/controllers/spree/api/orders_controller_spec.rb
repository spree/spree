require 'spec_helper'

module Spree
  describe Api::OrdersController do
    render_views

    let!(:order) { create(:order) }
    let(:variant) { create(:variant) }
    let(:line_item) { create(:line_item) }

    let(:attributes) { [:number, :item_total, :display_total, :total,
                        :state, :adjustment_total,
                        :user_id, :created_at, :updated_at,
                        :completed_at, :payment_total, :shipment_state,
                        :payment_state, :email, :special_instructions,
                        :total_quantity, :display_item_total] }

    let(:address_params) { { :country_id => Country.first.id, :state_id => State.first.id } }

    let(:billing_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                              :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                              :country_id => Country.first.id, :state_id => State.first.id} }

    let(:shipping_address) { { :firstname => "Tiago", :lastname => "Motta", :address1 => "Av Paulista",
                               :city => "Sao Paulo", :zipcode => "1234567", :phone => "12345678",
                               :country_id => Country.first.id, :state_id => State.first.id} }

    let!(:payment_method) { create(:payment_method) }

    let(:current_api_user) do
      user = Spree.user_class.new(:email => "spree@example.com")
      user.generate_spree_api_key!
      user
    end

    before do
      stub_authentication!
    end

    it "cannot view all orders" do
      api_get :index
      assert_unauthorized!
    end

    context "the current api user is not persisted" do
      let(:current_api_user) { double(persisted?: false) }

      it "returns a 401" do
        api_get :mine

        response.status.should == 401
      end
    end

    context "the current api user is authenticated" do
      let(:current_api_user) { order.user }
      let(:order) { create(:order, line_items: [line_item]) }

      it "can view all of their own orders" do
        api_get :mine

        response.status.should == 200
        json_response["pages"].should == 1
        json_response["current_page"].should == 1
        json_response["orders"].length.should == 1
        json_response["orders"].first["number"].should == order.number
        json_response["orders"].first["line_items"].length.should == 1
        json_response["orders"].first["line_items"].first["id"].should == line_item.id
      end

      it "can filter the returned results" do
        api_get :mine, q: {completed_at_not_null: 1}

        response.status.should == 200
        json_response["orders"].length.should == 0
      end
    end

    it "can view their own order" do
      Order.any_instance.stub :user => current_api_user
      api_get :show, :id => order.to_param
      response.status.should == 200
      json_response.should have_attributes(attributes)
      json_response["adjustments"].should be_empty
      json_response["credit_cards"].should be_empty
    end

    it "orders contain the basic checkout steps" do
      Order.any_instance.stub :user => current_api_user
      api_get :show, :id => order.to_param
      response.status.should == 200
      json_response["checkout_steps"].should == ["address", "delivery", "complete"]
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

    it "can view an order if the token is known" do
      api_get :show, :id => order.to_param, :order_token => order.token
      response.status.should == 200
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

    it "can create an order" do
      api_post :create, :order => { :line_items => { "0" => { :variant_id => variant.to_param, :quantity => 5 } } }
      response.status.should == 201
      order = Order.last
      order.line_items.count.should == 1
      order.line_items.first.variant.should == variant
      order.line_items.first.quantity.should == 5
      json_response["token"].should_not be_blank
      json_response["state"].should == "cart"
      order.user.should == current_api_user
      order.email.should == current_api_user.email
      json_response["user_id"].should == current_api_user.id
    end

    # Regression test for #3404
    it "can specify additional parameters for a line item" do
      Order.should_receive(:create!).and_return(order = Spree::Order.new)
      order.stub(:associate_user!)
      order.stub_chain(:contents, :add).and_return(line_item = double('LineItem'))
      line_item.should_receive(:update_attributes).with("special" => true)

      controller.stub(permitted_line_item_attributes: [:id, :variant_id, :quantity, :special])
      api_post :create, :order => { 
        :line_items => {
          "0" => {
            :variant_id => variant.to_param, :quantity => 5, :special => true
          }
        }
      }
      response.status.should == 201
    end

    it "cannot arbitrarily set the line items price" do
      api_post :create, :order => {
        :line_items => {
          "0" => {
            :price => 33.0, :variant_id => variant.to_param, :quantity => 5
          }
        }
      }

      expect(response.status).to eq 201
      expect(Order.last.line_items.first.price.to_f).to eq(variant.price)
    end

    context "import" do
      let(:tax_rate) { create(:tax_rate, amount: 0.05, calculator: Calculator::DefaultTax.create) }
      let(:other_variant) { create(:variant) }

      let(:order_params) do
        {
          :line_items => {
            "0" => { :variant_id => variant.to_param, :quantity => 5 },
            "1" => { :variant_id => other_variant.to_param, :quantity => 5 }
          }
        }
      end

      before do
        Zone.stub default_tax: tax_rate.zone
        current_api_user.stub has_spree_role?: true
      end

      it "sets channel" do
        api_post :create, :order => { channel: "amazon" }
        expect(json_response['channel']).to eq "amazon"
      end

      it "doesnt persist any automatic tax adjustment" do
        expect {
          api_post :create, :order => order_params.merge(:import => true)
        }.not_to change { Adjustment.count }

        expect(response.status).to eq 201
      end

      it "doesnt blow up when passing a sku into line items hash" do
        order_params[:line_items]["0"][:sku] = variant.sku
        order_params[:line_items]["0"][:variant_id] = nil
        order_params[:line_items]["1"][:sku] = other_variant.sku

        api_post :create, :order => order_params
        expect(response.status).to eq 201
      end
    end

    # Regression test for #3404
    it "does not update line item needlessly" do
      Order.should_receive(:create!).and_return(order = Spree::Order.new)
      order.stub(:associate_user!)
      order.stub_chain(:contents, :add).and_return(line_item = double('LineItem'))
      line_item.should_not_receive(:update_attributes)
      api_post :create, :order => { 
        :line_items => {
          "0" => {
            :variant_id => variant.to_param, :quantity => 5
          }
        }
      }
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

      context "line_items hash not present in request" do
        it "responds successfully" do
          api_put :update, :id => order.to_param, :order => {
            :email => "hublock@spreecommerce.com"
          }

          expect(response).to be_success
        end
      end

      it "updates quantities of existing line items" do
        api_put :update, :id => order.to_param, :order => {
          :line_items => {
            0 => { :id => line_item.id, :quantity => 10 }
          }
        }

        response.status.should == 200
        json_response['line_items'].count.should == 1
        json_response['line_items'].first['quantity'].should == 10
      end

      it "adds an extra line item" do
        variant2 = create(:variant)
        api_put :update, :id => order.to_param, :order => {
          :line_items => {
            0 => { :id => line_item.id, :quantity => 10 },
            1 => { :variant_id => variant2.id, :quantity => 1}
          }
        }

        response.status.should == 200
        json_response['line_items'].count.should == 2
        json_response['line_items'][0]['quantity'].should == 10
        json_response['line_items'][1]['variant_id'].should == variant2.id
        json_response['line_items'][1]['quantity'].should == 1
      end

      it "cannot change the price of an existing line item" do
        api_put :update, :id => order.to_param, :order => {
          :line_items => {
            0 => { :id => line_item.id, :price => 0 }
          }
        }

        response.status.should == 200
        json_response['line_items'].count.should == 1
        expect(json_response['line_items'].first['price'].to_f).to_not eq(0)
        expect(json_response['line_items'].first['price'].to_f).to eq(line_item.variant.price)
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
              0 => { :id => line_item.id, :quantity => 10 }
            }
          }
          expect(order.reload.shipments).to be_empty
        end
      end

      context "with a line item" do
        let(:order_with_line_items) do
          order = create(:order_with_line_items)
          create(:adjustment, :adjustable => order)
          order
        end

        it "can empty an order" do
          order_with_line_items.adjustments.count.should be == 1
          api_put :empty, :id => order_with_line_items.to_param
          response.status.should == 200
          order_with_line_items.reload
          order_with_line_items.line_items.should be_empty
          order_with_line_items.adjustments.should be_empty
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

        context "when in delivery" do
          let!(:shipping_method) do
            FactoryGirl.create(:shipping_method).tap do |shipping_method|
              shipping_method.calculator.preferred_amount = 10
              shipping_method.calculator.save
            end
          end

          before do
            order.ship_address = FactoryGirl.create(:address)
            order.state = 'delivery'
            order.save
          end

          it "returns available shipments for an order" do
            api_get :show, :id => order.to_param
            response.status.should == 200
            json_response["shipments"].should_not be_empty
            shipment = json_response["shipments"][0]
            # Test for correct shipping method attributes
            # Regression test for #3206
            shipment["shipping_methods"].should_not be_nil
            json_shipping_method = shipment["shipping_methods"][0]
            json_shipping_method["id"].should == shipping_method.id
            json_shipping_method["name"].should == shipping_method.name
            json_shipping_method["zones"].should_not be_empty
            json_shipping_method["shipping_categories"].should_not be_empty

            # Test for correct shipping rates attributes
            # Regression test for #3206
            shipment["shipping_rates"].should_not be_nil
            shipping_rate = shipment["shipping_rates"][0]
            shipping_rate["name"].should == json_shipping_method["name"]
            shipping_rate["cost"].should == "10.0"
            shipping_rate["selected"].should be_true
            shipping_rate["display_cost"].should == "$10.00"

            shipment["stock_location_name"].should_not be_blank
            manifest_item = shipment["manifest"][0]
            manifest_item["quantity"].should == 1
            manifest_item["variant"].should have_attributes([:id, :name, :sku, :price])
          end
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

      it "responds with orders updated_at with miliseconds precision" do
        api_get :index
        milisecond = order.updated_at.strftime("%L")
        updated_at = json_response["orders"].first["updated_at"]

        expect(updated_at.split("T").last).to have_content(milisecond)
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

      context "creation" do
        it "can arbitrarily set the line items price" do
          api_post :create, :order => {
            :line_items => {
              "0" => {
                :price => 33.0, :variant_id => variant.to_param, :quantity => 5
              }
            }
          }

          expect(response.status).to eq 201
          expect(Order.last.line_items.first.price.to_f).to eq(33.0)
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

