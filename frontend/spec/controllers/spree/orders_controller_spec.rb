require 'spec_helper'

describe Spree::OrdersController do
  let(:user) { create(:user) }
  let(:order) { mock_model(Spree::Order, :number => "R123", :reload => nil, :save! => true, :coupon_code => nil, :user => user, :completed? => false)}
  before do
    Spree::Order.stub(:find).with(1).and_return(order)
  end

  context "#populate" do
    before { Spree::Order.stub(:new).and_return(order) }

    it "should create a new order when none specified" do
      Spree::Order.should_receive(:new).and_return order
      spree_post :populate, {}, {}
      session[:order_id].should == order.id
    end

    context "with Variant" do
      before do
        @variant = mock_model(Spree::Variant)
        Spree::Variant.should_receive(:find).and_return @variant
      end

      it "should handle single variant/quantity pair" do
        order.should_receive(:add_variant).with(@variant, 2)
        spree_post :populate, {:order_id => 1, :variants => {@variant.id => 2}}
      end
      it "should handle multiple variant/quantity pairs with shared quantity" do
        @variant.stub(:product_id).and_return(10)
        order.should_receive(:add_variant).with(@variant, 1)
        spree_post :populate, {:order_id => 1, :products => {@variant.product_id => @variant.id}, :quantity => 1}
      end
      it "should handle multiple variant/quantity pairs with specific quantity" do
        @variant.stub(:product_id).and_return(10)
        order.should_receive(:add_variant).with(@variant, 3)
        spree_post :populate, {:order_id => 1, :products => {@variant.product_id => @variant.id}, :quantity => {@variant.id.to_s => 3}}
      end
    end
  end

  context "#update" do
    before do
      order.stub(:update_attributes).and_return true
      order.stub(:line_items).and_return([])
      order.stub(:line_items=).with([])
      Spree::Order.stub(:find_by_id).and_return(order)
    end

    it "should not result in a flash success" do
      spree_put :update, {}, {:order_id => 1}
      flash[:success].should be_nil
    end

    it "should render the edit view (on failure)" do
      order.stub(:update_attributes).and_return false
      order.stub(:errors).and_return({:number => "has some error"})
      spree_put :update, {}, {:order_id => 1}
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
      controller.stub!(:current_order).and_return(order)
      order.should_receive(:empty!)
      spree_put :empty
      response.should redirect_to(spree.cart_path)
    end
  end

  context "does not apply invalid coupon code" do
    let(:persisted_order) { create(:order) }

    let(:promotion) do
      Spree::Promotion.create({
        :name => "TestPromo",
        :code => "TEST1",
        :expires_at => 1.day.from_now,
        :created_at => 1.day.ago,
        :event_name => "spree.checkout.coupon_code_added",
        :match_policy => "any"
      }, :without_protection => true)
    end

    before do
      controller.stub :current_user => user
      controller.stub :current_order => persisted_order
    end

    it "and informs of invalidity" do
      controller.should_not_receive(:fire_event).
                 with('spree.checkout.coupon_code_added', hash_including(:coupon_code => 12345))
      spree_put :update, :order => { :coupon_code => 12345 }
      flash[:error].should == I18n.t(:coupon_code_not_found)
      response.should render_template :edit
    end
  end
end
