require 'spec_helper'

describe Spree::Core::Search::Base do

  before :each do
    include ::Spree::ProductFilters
    @product1 = Factory(:product, :name => "RoR Mug", :price => 9.00, :on_hand => 1)
    @product2 = Factory(:product, :name => "RoR Shirt", :price => 11.00, :on_hand => 1)
  end

  it "returns all products by default" do
    params = { :per_page => "" }
    searcher = Spree::Core::Search::Base.new(params)
    searcher.retrieve_products.count.should eq 2
  end

  it "maps search params to named scopes" do
    params = { :per_page => "",
               :search => { "price_range_any" => ["Under $10.00"] }}
    searcher = Spree::Core::Search::Base.new(params)
    searcher.send(:get_base_scope).to_sql.should match /<= 10/
    searcher.retrieve_products.count.should eq 1
  end

  it "maps multiple price_range_any filters" do
    params = { :per_page => "",
               :search => { "price_range_any" => ["Under $10.00", "$10.00 - $15.00"] }}
    searcher = Spree::Core::Search::Base.new(params)
    searcher.send(:get_base_scope).to_sql.should match /<= 10/
    searcher.send(:get_base_scope).to_sql.should match /between 10 and 15/
    searcher.retrieve_products.count.should eq 2
  end

  it "uses metasearch if scope not found" do
    params = { :per_page => "",
               :search => { "name_does_not_contain" => "Shirt" }}
    searcher = Spree::Core::Search::Base.new(params)
    searcher.retrieve_products.count.should eq 1
  end

end
