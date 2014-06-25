require 'spec_helper'

describe "Rabl Cache", :caching => true do
  let!(:user)  { create(:admin_user) }

  before do
    create(:variant) 
    user.generate_spree_api_key!
    Spree::Product.count.should == 1
  end
  
  it "doesn't create a cache key collision for models with different rabl templates" do
    get "/api/variants", :token => user.spree_api_key
    response.status.should == 200

    # Make sure we get a non master variant
    variant_a = JSON.parse(response.body)['variants'].select do |v|
      !v['is_master']
    end.first

    variant_a['is_master'].should be_false
    variant_a['stock_items'].should_not be_nil

    get "/api/products/#{Spree::Product.first.id}", :token => user.spree_api_key
    response.status.should == 200
    variant_b = JSON.parse(response.body)['variants'].last
    variant_b['is_master'].should be_false

    variant_a['id'].should == variant_b['id']
    variant_b['stock_items'].should be_nil
  end
end
