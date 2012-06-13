require 'spec_helper'

describe Spree::Admin::ProductsController do
  context "#index" do
    it "should not allow JSON request without a valid token" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      expect {
        spree_get :index, {:format => :json}
      }.to raise_error ActionController::InvalidAuthenticityToken
    end

    it "should allow JSON request with missing token if forgery protection is disabled" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      spree_get :index, {:format => :json}
      response.should be_success
    end

    it "should allow JSON request with invalid token if forgery protection is disabled" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(false)
      spree_get :index, {:authenticity_token => "XYZZY", :format => :json}
      response.should be_success
    end

    it "should allow JSON request with a valid token" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      controller.stub :form_authenticity_token => "123456"
      spree_get :index, {:authenticity_token => "123456", :format => :json}
      response.should be_success
    end

    it "should allow JSON request when token has URL(+,&,=) characters" do
      controller.should_receive(:protect_against_forgery?).at_least(:once).and_return(true)
      controller.stub :form_authenticity_token => "1+2=3&4'5/6?"
      spree_get :index, {:authenticity_token => "1+2%3D3%264%275/6%3F", :format => :json}
      response.should be_success
    end

    # Regression test for GH #538
    it "cannot find a non-existent product" do
      spree_get :edit, :id => "non-existent-product"
      response.should redirect_to(spree.admin_products_path)
      flash[:error].should eql("Product is not found")
    end

    # Regression test for #1259
    it "can find a product by SKU" do
      product = create(:product, :sku => "ABC123")
      spree_get :index, :q => { :sku_start => "ABC123" }
      assigns[:collection].should_not be_empty
      assigns[:collection].should include(product)
    end

    it "JSON request can find a product" do
      product = create(:product, :sku => "ABC123", :name => "Alpha")
      spree_xhr_get :index, { :q => "Alpha", :format => :json }
      assigns[:collection].should_not be_empty
      assigns[:collection].should include(product)
    end
  end

  context "creating a product" do
    
    include_context "product prototype"
  
    it "should create product" do
      spree_get :new
      response.should render_template("admin/products/new")
    end

    it "should create product from prototype" do
      spree_post :create, :product => product_attributes.merge(:prototype_id => prototype.id)
      product = Spree::Product.last
      response.should redirect_to(spree.edit_admin_product_path(product))
      prototype.properties.each do |property|
        product.properties.should include(property)
      end
      prototype.option_types.each do |ot|
        product.option_types.should include(ot)
      end
      product.variants_including_master.length.should == 1
    end
    
    it "should create product from prototype with option values hash" do
      spree_post :create, :product => product_attributes.merge(:prototype_id => prototype.id, :option_values_hash => option_values_hash)
      product = Spree::Product.last
      response.should redirect_to(spree.edit_admin_product_path(product))
      option_values_hash.each do |option_type_id, option_value_ids|
        Spree::ProductOptionType.where(:product_id => product.id, :option_type_id => option_type_id).first.should_not be_nil
      end
      product.variants.length.should == 3
    end
    
  end

  # regression test for #1370
  context "adding properties to a product" do
    let!(:product) { create(:product) }
    specify do
      spree_put :update, :id => product.to_param, :product => { :product_properties_attributes => { "1" => { :property_name => "Foo", :value => "bar" } } }
      flash[:notice].should == "Product #{product.name.inspect} has been successfully updated!"
    end

  end
  

  # regression test for #801
  context "destroying a product" do
    let(:product) do
      product = create(:product)
      create(:variant, :product => product)
      product
    end

    it "deletes all the variants (including master) for the product" do
      spree_delete :destroy, :id => product
      product.reload.deleted_at.should_not be_nil
      product.variants_including_master.each do |variant|
        varaint.reload.deleted_at.should_not be_nil
      end
    end
  end
end
