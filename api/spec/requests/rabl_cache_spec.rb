require 'spec_helper'

describe "Rabl Cache", :type => :request, :caching => true do
  let!(:user)  { create(:admin_user) }

  before do
    create(:variant) 
    user.generate_spree_api_key!
    expect(Spree::Product.count).to eq(1)
  end
  
  it "doesn't create a cache key collision for models with different rabl templates" do
    get "/api/v1/variants", :token => user.spree_api_key
    expect(response.status).to eq(200)

    # Make sure we get a non master variant
    variant_a = JSON.parse(response.body)['variants'].select do |v|
      !v['is_master']
    end.first

    expect(variant_a['is_master']).to be false
    expect(variant_a['stock_items']).not_to be_nil

    get "/api/v1/products/#{Spree::Product.first.id}", :token => user.spree_api_key
    expect(response.status).to eq(200)
    variant_b = JSON.parse(response.body)['variants'].last
    expect(variant_b['is_master']).to be false

    expect(variant_a['id']).to eq(variant_b['id'])
    expect(variant_b['stock_items']).to be_nil
  end
end
