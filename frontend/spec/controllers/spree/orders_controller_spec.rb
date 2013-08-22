require 'spec_helper'

describe Spree::OrdersController do
  let(:user) { create(:user) }

  context "Order model mock" do
    let(:order) do
      mock_model(Spree::Order, :number => "R123",
                               :reload => nil,
                               :save! => true,
                               :coupon_code => nil,
                               :user => user,
                               :created_by => nil,
                               :completed? => false,
                               :currency => "USD",
                               :token => 'a1b2c3d4',
                               :shipments => [])
    end

    before do
      # Don't care about IP address or created_by being set here
      order.stub(:last_ip_address=)
      order.stub(:created_by=)
      # Don't care about shipments either as feature specs will cover it
      order.stub :ensure_updated_shipments
      Spree::Order.stub(:find).with(1).and_return(order)
      controller.stub(:try_spree_current_user => user)
    end

    context "#populate" do
      before { Spree::Order.stub(:new).and_return(order) }

      it "should create a new order when none specified" do
        Spree::Order.should_receive(:new).and_return order
        spree_post :populate, {}, {}
        session[:order_id].should == order.id
      end

      context "with Variant" do
        let(:populator) { double('OrderPopulator') }
        before do
          Spree::OrderPopulator.should_receive(:new).and_return(populator)
        end

        it "should handle single variant/quantity pair" do
          populator.should_receive(:populate).with("variants" => { 1 => "2" }).and_return(true)
          spree_post :populate, { :order_id => 1, :variants => { 1 => 2 } }
          response.should redirect_to spree.cart_path
        end

        it "should handle multiple variant/quantity pairs with shared quantity" do
          populator.should_receive(:populate).with("products" => { 1 => "2" }, "quantity" => "1").and_return(true)
          spree_post :populate, { :order_id => 1, :products => { 1 => 2 }, :quantity => 1 }
          response.should redirect_to spree.cart_path
        end
      end
    end

    context "#update" do
      before do
        order.stub(:update_attributes).and_return true
        order.stub(:line_items).and_return([])
        order.stub(:line_items=).with([])
        order.stub(:last_ip_address=)
        subject.should_receive(:current_order).at_least(:once).and_return(order)
      end

      it "should not result in a flash success" do
        spree_put :update, {}, {:order_id => 1}
        flash[:success].should be_nil
      end

      it "should render the edit view (on failure)" do
        order.stub(:update_attributes).and_return false
        order.stub(:errors).and_return({:email => "is invalid"})
        spree_put :update, { :order => { :email => "" } }, {:order_id => 1}
        response.should render_template :edit
      end

      it "should redirect to cart path (on success)" do
        order.stub(:update_attributes).and_return true
        spree_put :update, {}, {:order_id => 1}
        response.should redirect_to(spree.cart_path)
      end
    end

    context "#empty" do
      it "should destroy line items in the current order" do
        controller.stub(:current_order).and_return(order)
        order.should_receive(:empty!)
        spree_put :empty
        response.should redirect_to(spree.cart_path)
      end
    end

    # Regression test for #2750
    context "#update" do
      before do
        user.stub :last_incomplete_spree_order
        controller.stub :set_current_order
      end

      it "cannot update a blank order" do
        spree_put :update, :order => { :email => "foo" }
        flash[:error].should == Spree.t(:order_not_found)
        response.should redirect_to(spree.root_path)
      end
    end
  end

  context "line items quantity is 0" do
    let(:order) { Spree::Order.create }
    let(:variant) { create(:variant) }
    let!(:line_item) { order.contents.add(variant, 1) }

    before do
      controller.stub(:check_authorization)
      controller.stub(:current_order => order)
    end

    it "removes line items on update" do
      expect(order.line_items.count).to eq 1
      spree_put :update, :order => { line_items_attributes: { "0" => { id: line_item.id, quantity: 0 } } }
      expect(order.reload.line_items.count).to eq 0
    end
  end
end
