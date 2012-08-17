# coding: UTF-8

require 'spec_helper'

describe Spree::Product do
  before(:each) do
    reset_spree_preferences
  end

  context "#on_hand=" do
    it "should not complain of a missing master" do
      product = Spree::Product.new
      product.on_hand = 5
    end
  end

  it "should always have a master variant" do
    product = Spree::Product.new
    product.master.should_not be_nil
  end

  context 'product instance' do
    let(:product) { create(:product) }

    context '#duplicate' do
      before do
        product.stub :taxons => [create(:taxon)]
      end

      it 'duplicates product' do
        clone = product.duplicate
        clone.name.should == 'COPY OF ' + product.name
        clone.master.sku.should == 'COPY OF ' + product.master.sku
        clone.taxons.should == product.taxons
        clone.images.size.should == product.images.size
      end
    end

    context "#on_hand" do
      # Regression test for #898
      context 'returns the correct number of products on hand' do
        before do
          Spree::Config.set :track_inventory_levels => true
          product.master.stub :on_hand => 2
        end
        specify { product.on_hand.should == 2 }
      end
    end

    context "#price" do
      # Regression test for #1173
      it 'strips non-price characters' do
        product.price = "$10"
        product.price.should == 10.0
      end
    end
  end

  context "validations" do
    context "find_by_param" do

      context "permalink should be incremented until the value is not taken" do
        before do
          @other_product = create(:product, :name => 'zoo')
          @product1 = create(:product, :name => 'foo')
          @product2 = create(:product, :name => 'foo')
          @product3 = create(:product, :name => 'foo')
        end
        it "should have valid permalink" do
          @product1.permalink.should == 'foo'
          @product2.permalink.should == 'foo-1'
          @product3.permalink.should == 'foo-2'
        end
      end

      context "permalink should be incremented until the value is not taken when there are more than 10 products" do
        before do
          @products = 0.upto(11).map do
            create(:product, :name => 'foo')
          end
        end
        it "should have valid permalink" do
          @products[11].permalink.should == 'foo-11'
        end
      end

      context "permalink should be incremented until the value is not taken for similar names" do
        before do
          @other_product = create(:product, :name => 'foo bar')
          @product1 = create(:product, :name => 'foo')
          @product2 = create(:product, :name => 'foo')
          @product3 = create(:product, :name => 'foo')
        end
        it "should have valid permalink" do
          @product1.permalink.should == 'foo-1'
          @product2.permalink.should == 'foo-2'
          @product3.permalink.should == 'foo-3'
        end
      end

      context "permalink should be incremented until the value is not taken for similar names when there are more than 10 products" do
        before do
          @other_product = create(:product, :name => 'foo a')
          @products = 0.upto(11).map do
            create(:product, :name => 'foo')
          end
        end
        it "should have valid permalink" do
          @products[11].permalink.should == 'foo-12'
        end
      end

      context "permalink with quotes" do
        it "should be saved correctly" do
          product = create(:product, :name => "Joe's", :permalink => "joe's")
          product.permalink.should == "joe's"
        end

        context "existing" do
          before do
            create(:product, :name => "Joe's", :permalink => "joe's")
          end

          it "should be detected" do
            product = create(:product, :name => "Joe's", :permalink => "joe's")
            product.permalink.should == "joe's-1"
          end
        end
      end

      context "make_permalink should declare validates_uniqueness_of" do
        before do
          @product1 = create(:product, :name => 'foo')
          @product2 = create(:product, :name => 'foo')
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
      @product = create(:product, :name => "你好")
      @product.permalink.should == "ni-hao"
    end
  end

  context "properties" do
    it "should properly assign properties" do
      product = FactoryGirl.create :product
      product.set_property('the_prop', 'value1')
      product.property('the_prop').should == 'value1'

      product.set_property('the_prop', 'value2')
      product.property('the_prop').should == 'value2'
    end

    it "should not create duplicate properties when set_property is called" do
      product = FactoryGirl.create :product

      lambda {
        product.set_property('the_prop', 'value2')
        product.save
        product.reload
      }.should_not change(product.properties, :length)

      lambda {
        product.set_property('the_prop_new', 'value')
        product.save
        product.reload
        product.property('the_prop_new').should == 'value'
      }.should change { product.properties.length }.by(1)
    end
  end

  context '#create' do
    before do
      @prototype = create(:prototype)
      @product = Spree::Product.new(:name => "Foo", :price => 1.99)
    end

    context "when prototype is supplied" do
      before { @product.prototype_id = @prototype.id }

      it "should create properties based on the prototype" do
        @product.save
        @product.properties.count.should == 1
      end

    end

    context "when prototype with option types is supplied" do

      include_context "product prototype"

      before { @product.prototype_id = prototype.id }

      it "should create option types based on the prototype" do
        @product.save
        @product.option_type_ids.length.should == 1
        @product.option_type_ids.should == prototype.option_type_ids
      end

      it "should create product option types based on the prototype" do
        @product.save
        @product.product_option_types.map(&:option_type_id).should == prototype.option_type_ids
      end

      it "should create variants from an option values hash with one option type" do
        @product.option_values_hash = option_values_hash
        @product.save
        @product.variants.length.should == 3
      end

      it "should still create variants when option_values_hash is given but prototype id is nil" do
        @product.option_values_hash = option_values_hash
        @product.prototype_id = nil
        @product.save
        @product.option_type_ids.length.should == 1
        @product.option_type_ids.should == prototype.option_type_ids
        @product.variants.length.should == 3
      end

      it "should create variants from an option values hash with multiple option types" do
        color = build_option_type_with_values("color", %w(Red Green Blue))
        logo  = build_option_type_with_values("logo", %w(Ruby Rails Nginx))
        option_values_hash[color.id.to_s] = color.option_value_ids
        option_values_hash[logo.id.to_s] = logo.option_value_ids
        @product.option_values_hash = option_values_hash
        @product.save
        @product = @product.reload
        @product.option_type_ids.length.should == 3
        @product.variants.length.should == 27
      end
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
        product.variants.build(:on_hand => 100)
        product.stub :has_variants? => true
      end
      specify { product.has_stock?.should be_true }
    end
  end

  context "#images" do
    let(:product) { create(:product) }

    before do
      image = File.open(File.expand_path('../../../app/assets/images/noimage/product.png', __FILE__))
      Spree::Image.create({:viewable_id => product.master.id, :viewable_type => 'Spree::Variant',        :alt => "position 2", :attachment => image, :position => 2})
      Spree::Image.create({:viewable_id => product.master.id, :viewable_type => 'Spree::Variant',        :alt => "position 1", :attachment => image, :position => 1})
      Spree::Image.create({:viewable_id => product.master.id, :viewable_type => 'ThirdParty::Extension', :alt => "position 1", :attachment => image, :position => 2})
    end

    it "should only look for variant images to support third-party extensions" do
      product.images.size.should == 2
    end

    it "should be sorted by position" do
      product.images.map(&:alt).should eq(["position 1", "position 2"])
    end

  end

end
