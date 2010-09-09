require 'spec_helper'

describe OrdersController do

  let(:user) { mock_model User, :persistence_token => "foo" }
  let(:order) { mock_model(Order, :user => user).as_null_object }

  context "for a new order" do
    context "#populate" do
      before do
        controller.stub :authorize! => true
        Order.stub :create => order
      end

      it "should check if user is authorized for :create" do
        controller.stub :current_user => user
        controller.should_receive(:authorize!).with(:create, Order)
        post :populate
      end

      it "should store a guest token (for new guest order)" do
        controller.should_receive(:current_user).and_return(nil)
        post :populate
        session[:guest_token].should_not be_nil
      end

      it "should not store a guest token (for new registered user order)" do
        controller.stub :current_user => user
        post :populate
        session[:guest_token].should be_nil
      end

    end
  end

  context "for an existing order" do

    before do
      controller.stub :current_order => order
      controller.stub :current_user => user
    end

    context "#populate" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        post :populate
      end
    end

    context "#edit" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        get :edit
      end
    end

    context "#update" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        post :update
      end
    end

    context "#empty" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        post :empty
      end
    end

  end

end
