require 'spec_helper'

describe CheckoutController do
  let(:order) { Order.new }
  let(:user) { mock_model User, :anonymous? => true }

  before do
    order.stub :checkout_allowed? => true
    controller.stub :current_order => order
    order.stub :user => user
  end

  context "with registration step enabled" do
    before do
      controller.stub :check_authorization => true
      Spree::Auth::Config.set(:registration_step => true)
    end

    context "anoymous checkout" do
      it "should redirect to the registration step" do
        controller.stub :current_user => nil
        get :edit, { :state => "confirm" }
        response.should redirect_to checkout_registration_path
      end
    end

    context "authenticated user checkout" do
      it "should proceed to the first checkout step" do
        controller.stub :current_user => mock_model(User)
        get :edit, { :state => "confirm" }
        response.should render_template :edit
      end
    end

    context "guest user checkout" do
      it "should proceed to the first checkout step" do
        controller.stub :current_user => nil
        user.stub :anonymous? => false
        get :edit, { :state => "confirm" }
        #response.should redirect_to checkout_registration_path
        response.should render_template :edit
      end
    end
  end

  context "with registration step disabled" do
    before { Spree::Auth::Config.set(:registration_step => false) }
    context "#update" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        post :update, { :state => "confirm", :order => {} }
      end
    end

    context "#edit" do
      it "should check if user is authorized for :edit" do
        controller.should_receive(:authorize!).with(:edit, order)
        get :edit, { :state => "confirm", :order => {} }
      end
    end

    context "anonymous checkout" do
      it "should not redirect to the registration step" do
        controller.stub :check_authorization => true
        get :edit, { :state => "confirm" }
        response.should_not redirect_to checkout_registration_path
      end
    end
  end

  context "#registration" do
    before { controller.stub :check_authorization => true }

    it "should not check registration" do
      controller.should_not_receive :check_registration
      get :registration
    end
  end

  context "#update_registration" do
    let(:user) { user = mock_model(User, :save => true, :email= => nil) }

    before do
      controller.stub :check_authorization => true
      order.stub :user => user
    end

    it "should not check registration" do
      controller.should_not_receive :check_registration
      put :update_registration, { :order => {:email => "jobs@railsdog.com"} }
    end

    it "should render the registration view if unable to save" do
      order.should_receive(:update_attributes).with("email" => "invalid").and_return false
      put :update_registration, { :order => {:email => "invalid"} }
      response.should render_template :registration
    end

    it "should redirect to the checkout_path after saving" do
      put :update_registration, { :order => {:email => "jobs@railsdog.com"} }
      response.should redirect_to checkout_path
    end
  end

  context "#update" do

    context "save successful" do
      before do
        controller.stub :current_order => order
        order.stub(:update_attribute).and_return true
        order.should_receive(:update_attributes).and_return true
      end

      context "when in the confirm state" do
        before do
          order.stub :next => true
          order.stub :state => "complete"
          order.stub :number => "R123"
        end

        context "with an anonymous user" do
          before do
            user.stub :token => "ABC"
            user.stub :anonymous? => true
            user.stub :has_role? => true
            controller.stub :current_user => user
          end

          it "should redirect to the tokenized order view" do
            post :update, {:state => "confirm"}
            response.should redirect_to token_order_path("R123", "ABC")
          end

          it "should populate the flash message" do
            post :update, {:state => "confirm"}
            flash[:notice].should == I18n.t(:order_processed_successfully)
          end
        end

        context "with a registered user" do
          before do
            user.stub :anonymous? => false
            user.stub :has_role? => true
            controller.stub :current_user => mock_model(User, :has_role? => true)
          end

          it "should redirect to the standard order view" do
            post :update, {:state => "confirm"}
            response.should redirect_to order_path("R123")
          end
        end

      end
    end

  end

end
