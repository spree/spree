# coding: UTF-8

require 'spec_helper'

describe Spree::Product do
  before(:each) do
    reset_spree_preferences
  end

  context "shoulda validations" do
    let(:product) {Factory(:product)}
    it { should belong_to(:tax_category) }
    it { should belong_to(:shipping_category) }
    it { should have_many(:product_option_types) }
    it { should have_many(:option_types) }
    it { should have_many(:product_properties) }
    it { should have_many(:properties) }
    it { should have_many(:images) }
    it { should have_and_belong_to_many(:product_groups) }
    it { should have_and_belong_to_many(:taxons) }
    it "should validate price" do
      product.should be_valid
    end
    # it { should validate_presence_of(:price) }
    it { should validate_presence_of(:permalink) }
    it { should have_valid_factory(:product) }
  end

  context "validations" do
    context "find_by_param" do

      context "permalink should be incremented until the value is not taken" do
        before do
          @product1 = Factory(:product, :name => 'foo')
          @product2 = Factory(:product, :name => 'foo')
          @product3 = Factory(:product, :name => 'foo')
        end
        it "should have valid permalink" do
          @product1.permalink.should == 'foo'
          @product2.permalink.should == 'foo-1'
          @product3.permalink.should == 'foo-2'
        end
      end

      context "make_permalink should declare validates_uniqueness_of" do
        before do
          @product1 = Factory(:product, :name => 'foo')
          @product2 = Factory(:product, :name => 'foo')
          @product2.update_attributes(:permalink => 'foo')
        end

        it "should have an error" do
          @product2.errors.size.should == 1
        end

        it "should have error message that permalink is already taken" do
          @product2.errors.full_messages.first.should == 'Permalink has already been taken'
        end
      end

    end
  end

  context "permalink generation" do
    it "supports Chinese" do
      @product = Factory(:product, :name => "你好")
      @product.permalink.should == "ni-hao"
    end
  end

  context "scopes" do
    context ".group_by_products_id.count" do
      let(:product) { Factory(:product) }
      it 'produces a properly formed ordered-hash key' do
        expected_key = (ActiveRecord::Base.connection.adapter_name == 'PostgreSQL') ?
          Spree::Product.column_names.map{|col_name| product.send(col_name)} :
          product.id
        count_key = Spree::Product.group_by_products_id.count.keys.first
        [expected_key, count_key].each{|val| val.map!{|e| e.is_a?(Time) ? e.strftime("%Y-%m-%d %H:%M:%S") : e} if val.respond_to?(:map!)}
        count_key.should == expected_key
      end
    end

  end

  context '#add_properties_and_option_types_from_prototype' do
    let!(:property) { stub_model(Spree::Property) }

    let!(:prototype) do
      prototype = stub_model(Spree::Prototype)
      prototype.stub :properties => [property]
      prototype.stub :option_types => [stub_model(Spree::OptionType)] 
      prototype
    end

    let(:product) do
      product = stub_model(Spree::Product, :prototype_id => prototype.id)
      # The `set_master_variant_defaults` callback requires a master
      product.stub :master => stub_model(Spree::Variant)
      product
    end

    it 'should have one property' do
      Spree::Prototype.stub :find_by_id => prototype
      product.product_properties.should_receive(:create).with(:property => property)
      product.should_receive(:option_types=).with(prototype.option_types)
      product.run_callbacks(:create)
    end
  end

  context '#has_stock?' do
    let(:product) do
      product = stub_model(Spree::Product)
      product.stub :master => stub_model(Spree::Variant)
      product
    end

    context 'nothing in stock' do
      before do
        Spree::Config.set :track_inventory_levels => true
        product.master.stub :on_hand => 0
      end
      specify { product.has_stock?.should be_false }
    end

    context 'master variant has items in stock' do
      before do
        product.master.on_hand = 100
      end
      specify { product.has_stock?.should be_true }
    end

    context 'variant has items in stock' do
      before do
        Spree::Config.set :track_inventory_levels => true
        product.master.stub :on_hand => 0
        product.stub :variants => [stub_model(Spree::Variant, :on_hand => 100)]
      end
      specify { product.has_stock?.should be_true }
    end
  end

  context '#effective_tax_rate' do
    let(:product) { stub_model(Spree::Product) }

    it 'should check tax category for applicable rates' do
      tax_category = double("Tax Category")
      product.stub :tax_category => tax_category
      tax_category.should_receive(:effective_amount)
      product.effective_tax_rate
    end

    it 'should return default tax rate when no tax category is defined' do
      product.stub :tax_category => nil
      product.effective_tax_rate.should == Spree::TaxRate.default
    end

  end

end
