require 'spec_helper'

describe Spree::Admin::ProductsController do
  before do
    controller.stub :current_user => Factory(:admin_user)
  end

  context "#index" do
    it "should not allow JSON request without a valid token" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      expect {
        get :index, {:format => :json}
      }.to raise_error ActionController::InvalidAuthenticityToken
    end

    it "should allow JSON request with missing token if forgery protection is disabled" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      get :index, {:format => :json}
      response.should be_success
    end

    it "should allow JSON request with invalid token if forgery protection is disabled" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      get :index, {:authenticity_token => "XYZZY", :format => :json}
      response.should be_success
    end

    it "should allow JSON request with a valid token" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      controller.stub :form_authenticity_token => "123456"
      get :index, {:authenticity_token => "123456", :format => :json}
      response.should be_success
    end

    it "should allow JSON request when token has URL(+,&,=) characters" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      controller.stub :form_authenticity_token => "1+2=3&4'5/6?"
      get :index, {:authenticity_token => "1+2%3D3%264%275/6%3F", :format => :json}
      response.should be_success
    end

    # Regression test for GH #538
    it "cannot find a non-existent product" do
      lambda { get :edit, :id => "non-existent-product" }.should raise_error(ActiveRecord::RecordNotFound)
    end
  end

  # regression test for #801
  context "destroying a product" do
    let(:product) do
      product = Factory(:product)
      Factory(:variant, :product => product)
      product
    end

    it "deletes all the variants (including master) for the product" do
      delete :destroy, :id => product
      product.reload.deleted_at.should_not be_nil
      product.variants_including_master.each do |variant|
        varaint.reload.deleted_at.should_not be_nil
      end
    end
  end
end
