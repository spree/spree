# coding: UTF-8

require 'spec_helper'

module ThirdParty
  class Extension < ActiveRecord::Base
    # nasty hack so we don't have to create a table to back this fake model
    self.table_name = 'spree_products'
  end
end

describe Spree::Product do
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

      it 'calls #duplicate_extra' do
        Spree::Product.class_eval do
          def duplicate_extra(old_product)
            self.name = old_product.name.reverse
          end
        end

        clone = product.duplicate
        clone.name.should == product.name.reverse
      end
    end

    context "master variant" do
      context "when master variant changed" do
        before do
          product.master.sku = "Something changed"
        end

        it "saves the master" do
          product.master.should_receive(:save)
          product.save
        end
      end

      context "when master default price is a new record" do
        before do
          @price = product.master.build_default_price
          @price.price = 12
        end

        it "saves the master" do
          product.master.should_receive(:save)
          product.save
        end

        it "saves the default price" do
          proc do
            product.save
          end.should change{ @price.new_record? }.from(true).to(false)
        end

      end

      context "when master default price changed" do
        before do
          master = product.master
          master.default_price = create(:price, :variant => master)
          master.save!
          product.master.default_price.price = 12
        end

        it "saves the master" do
          product.master.should_receive(:save)
          product.save
        end

        it "saves the default price" do
          product.master.default_price.should_receive(:save)
          product.save
        end
      end

      context "when master variant and price haven't changed" do
        it "does not save the master" do
          product.master.should_not_receive(:save)
          product.save
        end
      end
    end

    context "product has no variants" do
      context "#destroy" do
        it "should set deleted_at value" do
          product.destroy
          product.deleted_at.should_not be_nil
          product.master.deleted_at.should_not be_nil
        end
      end
    end

    context "product has variants" do
      before do
        create(:variant, :product => product)
      end

      context "#destroy" do
        it "should set deleted_at value" do
          product.destroy
          product.deleted_at.should_not be_nil
          product.variants_including_master.all? { |v| !v.deleted_at.nil? }.should be_true
        end
      end
    end

    context "#price" do
      # Regression test for #1173
      it 'strips non-price characters' do
        product.price = "$10"
        product.price.should == 10.0
      end
    end

    context "#display_price" do
      before { product.price = 10.55 }

      context "with display_currency set to true" do
        before { Spree::Config[:display_currency] = true }

        it "shows the currency" do
          product.display_price.to_s.should == "$10.55 USD"
        end
      end

      context "with display_currency set to false" do
        before { Spree::Config[:display_currency] = false }

        it "does not include the currency" do
          product.display_price.to_s.should == "$10.55"
        end
      end

      context "with currency set to JPY" do
        before do
          product.master.default_price.currency = 'JPY'
          product.master.default_price.save!
          Spree::Config[:currency] = 'JPY'
        end

        it "displays the currency in yen" do
          product.display_price.to_s.should == "¥11"
        end
      end
    end

    context "#available?" do
      it "should be available if date is in the past" do
        product.available_on = 1.day.ago
        product.should be_available
      end

      it "should not be available if date is nil or in the future" do
        product.available_on = nil
        product.should_not be_available

        product.available_on = 1.day.from_now
        product.should_not be_available
      end
    end

    context "variants_and_option_values" do
      let!(:high) { create(:variant, product: product) }
      let!(:low) { create(:variant, product: product) }

      before { high.option_values.destroy_all }

      it "returns only variants with option values" do
        product.variants_and_option_values.should == [low]
      end
    end

    describe 'Variants sorting' do
      context 'without master variant' do
        it 'sorts variants by position' do
          product.variants.to_sql.should match(/ORDER BY (\`|\")spree_variants(\`|\").position ASC/)
        end
      end

      context 'with master variant' do
        it 'sorts variants by position' do
          product.variants_including_master.to_sql.should match(/ORDER BY (\`|\")spree_variants(\`|\").position ASC/)
        end
      end
    end

    context "has stock movements" do
      let(:product) { create(:product) }
      let(:variant) { product.master }
      let(:stock_item) { variant.stock_items.first }

      it "doesnt raise ReadOnlyRecord error" do
        Spree::StockMovement.create!(stock_item: stock_item, quantity: 1)
        expect { product.destroy }.not_to raise_error
      end
    end

    # Regression test for #3737 
    context "has stock items" do
      let(:product) { create(:product) }
      it "can retreive stock items" do
        product.master.stock_items.first.should_not be_nil
        product.stock_items.first.should_not be_nil
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

      context "permalinks must be unique" do
        before do
          @product1 = create(:product, :name => 'foo')
        end

        it "cannot create another product with the same permalink" do
          @product2 = create(:product, :name => 'foo')
          lambda do
            @product2.update_attributes(:permalink => @product1.permalink)
          end.should raise_error(ActiveRecord::RecordNotUnique)
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

  context "manual permalink override" do
    it "calling save_permalink with a parameter" do
      @product = create(:product, :name => "foo")
      @product.permalink.should == "foo"
      @product.name = "foobar"
      @product.save
      @product.permalink.should == "foo"
      @product.save_permalink(@product.name)
      @product.permalink.should == "foobar"
    end

    it "should be incremented until not taken with a parameter" do
      @product = create(:product, :name => "foo")
      @product2 = create(:product, :name => "foobar")
      @product.permalink.should == "foo"
      @product.name = "foobar"
      @product.save
      @product.permalink.should == "foo"
      @product.save_permalink(@product.name)
      @product.permalink.should == "foobar-1"
    end

    context "override permalink of deleted product" do 
      let(:product) { create(:product, :name => "foo") } 

      it "should create product with same permalink from name like deleted product" do 
        product.permalink.should == "foo" 
        product.destroy 
        
        new_product = create(:product, :name => "foo") 
        new_product.permalink.should == "foo" 
      end 
    end 
  end

  context "properties" do
    it "should properly assign properties" do
      product = create(:product)
      product.set_property('the_prop', 'value1')
      product.property('the_prop').should == 'value1'

      product.set_property('the_prop', 'value2')
      product.property('the_prop').should == 'value2'
    end

    it "should not create duplicate properties when set_property is called" do
      product = create(:product)

      expect {
        product.set_property('the_prop', 'value2')
        product.save
        product.reload
      }.not_to change(product.properties, :length)

      expect {
        product.set_property('the_prop_new', 'value')
        product.save
        product.reload
        product.property('the_prop_new').should == 'value'
      }.to change { product.properties.length }.by(1)
    end

    # Regression test for #2455
    it "should not overwrite properties' presentation names" do
      product = create(:product)
      Spree::Property.where(:name => 'foo').first_or_create!(:presentation => "Foo's Presentation Name")
      product.set_property('foo', 'value1')
      product.set_property('bar', 'value2')
      Spree::Property.where(:name => 'foo').first.presentation.should == "Foo's Presentation Name"
      Spree::Property.where(:name => 'bar').first.presentation.should == "bar"
    end
  end

  context '#create' do
    before do
      @prototype = create(:prototype)
      @product = Spree::Product.new(name: "Foo", price: 1.99, shipping_category_id: 1)
    end

    context "when prototype is supplied" do
      before { @product.prototype_id = @prototype.id }

      it "should create properties based on the prototype" do
        @product.save
        @product.properties.count.should == 1
      end

    end

    context "when prototype with option types is supplied" do
      def build_option_type_with_values(name, values)
        ot = create(:option_type, :name => name)
        values.each do |val|
          ot.option_values.create({:name => val.downcase, :presentation => val}, :without_protection => true)
        end
        ot
      end

      let(:prototype) do
        size = build_option_type_with_values("size", %w(Small Medium Large))
        create(:prototype, :name => "Size", :option_types => [ size ])
      end

      let(:option_values_hash) do
        hash = {}
        prototype.option_types.each do |i|
          hash[i.id.to_s] = i.option_value_ids
        end
        hash
      end

      before { @product.prototype_id = prototype.id }

      it "should create option types based on the prototype" do
        @product.save
        @product.option_type_ids.length.should == 1
        @product.option_type_ids.should == prototype.option_type_ids
      end

      it "should create product option types based on the prototype" do
        @product.save
        @product.product_option_types.pluck(:option_type_id).should == prototype.option_type_ids
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

  context "#images" do
    let(:product) { create(:product) }

    before do
      image = File.open(File.expand_path('../../../fixtures/thinking-cat.jpg', __FILE__))
      Spree::Image.create({:viewable_id => product.master.id, :viewable_type => 'Spree::Variant',        :alt => "position 2", :attachment => image, :position => 2})
      Spree::Image.create({:viewable_id => product.master.id, :viewable_type => 'Spree::Variant',        :alt => "position 1", :attachment => image, :position => 1})
      Spree::Image.create({:viewable_id => product.master.id, :viewable_type => 'ThirdParty::Extension', :alt => "position 1", :attachment => image, :position => 2})
    end

    it "should only look for variant images to support third-party extensions" do
      product.images.size.should == 2
    end

    it "should be sorted by position" do
      product.images.pluck(:alt).should eq(["position 1", "position 2"])
    end
  end

  # Regression tests for #2352
  context "classifications and taxons" do
    it "is joined through classifications" do
      reflection = Spree::Product.reflect_on_association(:taxons)
      reflection.options[:through] = :classifications
    end

    it "will delete all classifications" do
      reflection = Spree::Product.reflect_on_association(:classifications)
      reflection.options[:dependent] = :delete_all
    end
  end

  describe '#total_on_hand' do
    it 'should be infinite if track_inventory_levels is false' do
      Spree::Config[:track_inventory_levels] = false
      build(:product).total_on_hand.should eql(Float::INFINITY)
    end

    it 'should return master variants quantity' do
      product = build(:product)
      product.stub stock_items: [double(Spree::StockItem, count_on_hand: 5)]
      product.total_on_hand.should eql(5)
    end
  end
end
