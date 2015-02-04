require 'spec_helper'

describe Spree::Core::Search::Base do

  before do
    include Spree::Core::ProductFilters
    @taxon = create(:taxon, name: "Ruby on Rails")

    @product1 = create(:product, name: "RoR Mug", price: 9.00)
    @product1.taxons << @taxon
    @product2 = create(:product, name: "RoR Shirt", price: 11.00)
  end

  it "returns all products by default" do
    params = { :per_page => "" }
    searcher = Spree::Core::Search::Base.new(params)
    expect(searcher.retrieve_products.count).to eq(2)
  end

  context "when include_images is included in the initalization params" do
    let(:params) { { include_images: true, keyword: @product1.name, taxon: @taxon.id } }
    subject { described_class.new(params).retrieve_products }

    before do
      @product1.master.images.create(attachment_file_name: "Test", position: 2)
      @product1.master.images.create(attachment_file_name: "Test1", position: 1)
      @product1.reload
    end

    it "returns images in correct order" do
      expect(subject.first).to eq @product1
      expect(subject.first.images).to eq @product1.master.images
    end
  end

  it "switches to next page according to the page parameter" do
    @product3 = create(:product, :name => "RoR Pants", :price => 14.00)

    params = { :per_page => "2" }
    searcher = Spree::Core::Search::Base.new(params)
    expect(searcher.retrieve_products.count).to eq(2)

    params.merge! :page => "2"
    searcher = Spree::Core::Search::Base.new(params)
    expect(searcher.retrieve_products.count).to eq(1)
  end

  it "maps search params to named scopes" do
    params = { :per_page => "",
               :search => { "price_range_any" => ["Under $10.00"] }}
    searcher = Spree::Core::Search::Base.new(params)
    expect(searcher.send(:get_base_scope).to_sql).to match /<= 10/
    expect(searcher.retrieve_products.count).to eq(1)
  end

  it "maps multiple price_range_any filters" do
    params = { :per_page => "",
               :search => { "price_range_any" => ["Under $10.00", "$10.00 - $15.00"] }}
    searcher = Spree::Core::Search::Base.new(params)
    expect(searcher.send(:get_base_scope).to_sql).to match /<= 10/
    expect(searcher.send(:get_base_scope).to_sql).to match /between 10 and 15/i
    expect(searcher.retrieve_products.count).to eq(2)
  end

  it "uses ransack if scope not found" do
    params = { :per_page => "",
               :search => { "name_not_cont" => "Shirt" }}
    searcher = Spree::Core::Search::Base.new(params)
    expect(searcher.retrieve_products.count).to eq(1)
  end

  it "accepts a current user" do
    user = double
    searcher = Spree::Core::Search::Base.new({})
    searcher.current_user = user
    expect(searcher.current_user).to eql(user)
  end

  it "finds products in alternate currencies" do
    price = create(:price, :currency => 'EUR', :variant => @product1.master)
    searcher = Spree::Core::Search::Base.new({})
    searcher.current_currency = 'EUR'
    expect(searcher.retrieve_products).to eq([@product1])
  end

end
