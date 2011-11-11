require 'spec_helper'

describe Spree::Admin::OverviewController do
  context '#get_report_data' do
    it 'should not allow JSON request without a valid token' do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      expect {
        get :get_report_data, { :report => 'orders_totals', :name => '7_days', :format => :js }
      }.to raise_error ActionController::InvalidAuthenticityToken
    end

    it 'should allow JSON request with missing token if forgery protection is disabled' do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      get :get_report_data, { :report => 'orders_totals', :name => '7_days', :format => :js }
      response.should be_success
    end

    it 'should allow JSON request with invalid token if forgery protection is disabled' do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      get :get_report_data, { :report => 'orders_totals', :name => '7_days', :format => :js }
      response.should be_success
    end

    it 'should allow JSON request with a valid token' do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      controller.stub :form_authenticity_token => '123456'
      get :get_report_data, { :report => 'orders_totals', :name => '7_days', :authenticity_token => '123456', :format => :js }
      response.should be_success
    end
  end

  context "#best_selling_variants" do
    it "should return the 5 best selling variants" do
      product1 = Factory(:product, :name => "RoR Shirt")
      product2 = Factory(:product, :name => "RoR Jersey")
      product3 = Factory(:product, :name => "RoR Hat")
      product4 = Factory(:product, :name => "RoR Pants")
      product5 = Factory(:product, :name => "RoR Shoes")
      variant1 = Factory(:variant, :product => product1)
      variant2 = Factory(:variant, :product => product2)
      variant3 = Factory(:variant, :product => product3)
      variant4 = Factory(:variant, :product => product4)
      variant5 = Factory(:variant, :product => product5)
      order = Factory(:order, :state => 'complete')
      line_items = [
        Factory(:line_item, :variant => variant1, :quantity => 5, :order => order),
        Factory(:line_item, :variant => variant2, :quantity => 4, :order => order),
        Factory(:line_item, :variant => variant3, :quantity => 3, :order => order),
        Factory(:line_item, :variant => variant4, :quantity => 2, :order => order),
        Factory(:line_item, :variant => variant5, :quantity => 1, :order => order),
      ]
      order.line_items = line_items
      order.save
      order.stub(:process_payments!).and_raise(Spree::Core::GatewayError)
      Spree::Config.set :allow_checkout_on_gateway_error => true
      order.finalize!

      best = @controller.send(:best_selling_variants)
      best[0][0].should == "RoR Shirt"
      best[1][0].should == "RoR Jersey"
      best[2][0].should == "RoR Hat"
      best[3][0].should == "RoR Pants"
      best[4][0].should == "RoR Shoes"
    end
  end

  context "#top_grossing_variants" do
    it "should return the 5 best selling variants" do
      product1 = Factory(:product, :name => "RoR Shirt")
      product2 = Factory(:product, :name => "RoR Jersey")
      product3 = Factory(:product, :name => "RoR Hat")
      product4 = Factory(:product, :name => "RoR Pants")
      product5 = Factory(:product, :name => "RoR Shoes")
      variant1 = Factory(:variant, :product => product1, :price => "50.00")
      variant2 = Factory(:variant, :product => product2, :price => "40.00")
      variant3 = Factory(:variant, :product => product3, :price => "30.00")
      variant4 = Factory(:variant, :product => product4, :price => "20.00")
      variant5 = Factory(:variant, :product => product5, :price => "10.00")
      order = Factory(:order, :state => 'complete')
      line_items = [
        Factory(:line_item, :variant => variant1, :quantity => 5, :order => order),
        Factory(:line_item, :variant => variant2, :quantity => 4, :order => order),
        Factory(:line_item, :variant => variant3, :quantity => 3, :order => order),
        Factory(:line_item, :variant => variant4, :quantity => 2, :order => order),
        Factory(:line_item, :variant => variant5, :quantity => 1, :order => order),
      ]
      order.line_items = line_items
      order.save
      order.stub(:process_payments!).and_raise(Spree::Core::GatewayError)
      Spree::Config.set :allow_checkout_on_gateway_error => true
      order.finalize!

      top_grossing = @controller.send(:top_grossing_variants)
      top_grossing[0][0].should == "RoR Shirt"
      top_grossing[1][0].should == "RoR Jersey"
      top_grossing[2][0].should == "RoR Hat"
      top_grossing[3][0].should == "RoR Pants"
      top_grossing[4][0].should == "RoR Shoes"
    end
  end
end
