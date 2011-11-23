require 'spec_helper'

describe Spree::Product do
  before(:each) do
    @configuration ||= Spree::AppConfiguration.find_or_create_by_name("Default configuration")
  end

  context "shoulda validations" do
    it { should belong_to(:tax_category) }
    it { should belong_to(:shipping_category) }
    it { should have_many(:product_option_types) }
    it { should have_many(:option_types) }
    it { should have_many(:product_properties) }
    it { should have_many(:properties) }
    it { should have_many(:images) }
    it { should have_and_belong_to_many(:product_groups) }
    it { should have_and_belong_to_many(:taxons) }
    it { should validate_presence_of(:price) }
    it { should validate_presence_of(:permalink) }
    it { should have_valid_factory(:product) }
  end

  context "factory_girl" do
    let(:product) { Factory(:product) }
    it 'should have a saved product record' do
      product.new_record?.should be_false
    end
    it 'should have zero properties record' do
      product.product_properties.size.should == 0
    end
    it 'should have a master variant' do
      product.master.should be_true
    end
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
    let!(:prototype) { Factory(:prototype) }
    let(:product) { Factory(:product, :prototype_id => prototype.id) }
    it 'should have one property' do
      product.product_properties.size.should == 1
    end
  end

  context '#has_stock?' do
    let(:product) { Factory(:product) }
    context 'nothing in stock' do
      before do
        Spree::Config.set :track_inventory_levels => true
        product.master.update_attribute(:on_hand, 0)
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
        product.master.update_attribute(:on_hand, 0)
        Factory(:variant, :product => product, :on_hand => 100, :is_master => false, :deleted_at => nil)
        product.reload
      end
      specify { product.has_stock?.should be_true }
    end
  end

  context '#effective_tax_rate' do
    let(:product) { Factory(:product) }

    it 'should check tax category for applicable rates' do
      Spree::TaxCategory.any_instance.should_receive(:effective_amount)
      product.effective_tax_rate
    end

    it 'should return default tax rate when no tax category is defined' do
      product.update_attribute(:tax_category, nil)
      product.effective_tax_rate.should == Spree::TaxRate.default
    end

  end

end
