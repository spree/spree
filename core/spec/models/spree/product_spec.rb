# coding: UTF-8

require 'spec_helper'

module ThirdParty
  class Extension < Spree::Base
    # nasty hack so we don't have to create a table to back this fake model
    self.table_name = 'spree_products'
  end
end

describe Spree::Product, type: :model do

  describe 'Associations' do
    it 'should have many promotions' do
      is_expected.to have_many(:promotions).
        class_name('Spree::Promotion').through(:promotion_rules)
    end

    it 'should have many possible_promotions' do
      is_expected.to have_many(:possible_promotions).
        class_name('Spree::Promotion').through(:promotion_rules).source(:promotion)
    end

    it do
      is_expected.to have_many(:variants).
        class_name('Spree::Variant').
        inverse_of(:product).
        conditions(is_master: false).
        order(:position)
    end

    it do
      is_expected.to have_many(:variants_including_master).
        class_name('Spree::Variant').
        inverse_of(:product).
        order(:position)
    end
  end

  context 'product instance' do
    let(:product) { create(:product) }
    let(:variant) { create(:variant, product: product) }

    context '#duplicate' do
      before do
        allow(product).to receive_messages taxons: [create(:taxon)]
      end

      it 'duplicates product' do
        clone = product.duplicate
        expect(clone.name).to eq('COPY OF ' + product.name)
        expect(clone.master.sku).to eq('COPY OF ' + product.master.sku)
        expect(clone.taxons).to eq(product.taxons)
        expect(clone.images.size).to eq(product.images.size)
      end

      it 'calls #duplicate_extra' do
        expect_any_instance_of(Spree::Product).to receive(:duplicate_extra)
          .with(product)
        expect(product).to_not receive(:duplicate_extra)
        product.duplicate
      end
    end

    context "master variant" do

      context "when master variant changed" do
        before do
          product.master.sku = "Something changed"
        end

        it "saves the master" do
          expect(product.master).to receive(:save!)
          product.save
        end
      end

      context "when master default price changed" do
        before do
          master = product.master
          master.default_price.price = 11
          master.save!
          product.master.default_price.price = 12
        end

        it "saves the master" do
          expect(product.master).to receive(:save!)
          product.save
        end

        it "saves the default price" do
          expect(product.master.default_price).to receive(:save)
          product.save
        end
      end

      context "when master variant and price haven't changed" do
        it "does not save the master" do
          expect(product.master).not_to receive(:save!)
          product.save
        end
      end
    end

    context "product has no variants" do
      context "#destroy" do
        it "should set deleted_at value" do
          product.destroy
          expect(product.deleted_at).not_to be_nil
          expect(product.master.reload.deleted_at).not_to be_nil
        end
      end
    end

    context "product has variants" do
      before do
        create(:variant, product: product)
      end

      context "#destroy" do
        it "should set deleted_at value" do
          product.destroy
          expect(product.deleted_at).not_to be_nil
          expect(product.variants_including_master.all? { |v| !v.deleted_at.nil? }).to be true
        end
      end
    end

    context "#price" do
      # Regression test for #1173
      it 'strips non-price characters' do
        product.price = "$10"
        expect(product.price).to eq(10.0)
      end
    end

    context "#display_price" do
      before { product.price = 10.55 }

      it "shows the amount" do
        expect(product.display_price.to_s).to eq("$10.55")
      end

      context "with currency set to JPY" do
        before do
          product.master.default_price.currency = 'JPY'
          product.master.default_price.save!
          Spree::Config[:currency] = 'JPY'
        end

        it "displays the currency in yen" do
          expect(product.display_price.to_s).to eq("¥11")
        end
      end
    end

    context "#available?" do
      it "should be available if date is in the past" do
        product.available_on = 1.day.ago
        expect(product).to be_available
      end

      it "should not be available if date is nil or in the future" do
        product.available_on = nil
        expect(product).not_to be_available

        product.available_on = 1.day.from_now
        expect(product).not_to be_available
      end

      it "should not be available if destroyed" do
        product.destroy
        expect(product).not_to be_available
      end
    end

    context "#can_supply?" do
      it "should be true" do
        expect(product.can_supply?).to be(true)
      end

      it "should be false" do
        product.variants_including_master.each { |v| v.stock_items.update_all count_on_hand: 0, backorderable: false }
        expect(product.can_supply?).to be(false)
      end
    end

    context "variants_and_option_values" do
      let!(:high) { create(:variant, product: product) }
      let!(:low) { create(:variant, product: product) }

      before { high.option_values.destroy_all }

      it "returns only variants with option values" do
        expect(product.variants_and_option_values).to eq([low])
      end
    end

    context "has stock movements" do
      let(:variant) { product.master }
      let(:stock_item) { variant.stock_items.first }

      it "doesnt raise ReadOnlyRecord error" do
        Spree::StockMovement.create!(stock_item: stock_item, quantity: 1)
        expect { product.destroy }.not_to raise_error
      end
    end

    # Regression test for #3737
    context "has stock items" do
      it "can retrieve stock items" do
        expect(product.master.stock_items.first).not_to be_nil
        expect(product.stock_items.first).not_to be_nil
      end
    end

    context "slugs" do

      it "normalizes slug on update validation" do
        product.slug = "hey//joe"
        product.valid?
        expect(product.slug).not_to match "/"
      end

      it "stores old slugs in FriendlyIds history" do
        # create_slug is a private method, included by FriendlyId::History
        # it's effect is rather complex and dependent on state and config.
        # However, when a new slug is set, it should call slugs.create!
        expect(product.slugs).to receive(:create!)
        # Set it, otherwise the create_slug method avoids writing a new one
        product.slug = "custom-slug"
        product.run_callbacks :save
      end

      context "when product destroyed" do

        it "renames slug" do
          expect { product.destroy }.to change { product.slug }
        end

        context "when slug is already at or near max length" do

          before do
            product.slug = "x" * 255
            product.save!
          end

          it "truncates renamed slug to ensure it remains within length limit" do
            product.destroy
            expect(product.slug.length).to eq 255
          end

        end

      end

      it "validates slug uniqueness" do
        existing_product = product
        new_product = create(:product)
        new_product.slug = existing_product.slug

        expect(new_product.valid?).to eq false
      end

      it "falls back to 'name-sku' for slug if regular name-based slug already in use" do
        product1 = build(:product)
        product1.name = "test"
        product1.sku = "123"
        product1.save!

        product2 = build(:product)
        product2.name = "test"
        product2.sku = "456"
        product2.save!

        expect(product2.slug).to eq 'test-456'
      end
    end

    describe "#discontinue_on_must_be_later_than_available_on" do
      before { product.available_on = Date.today }

      context "available_on is a date earlier than discontinue_on" do
        before { product.discontinue_on = 5.days.from_now }

        it "is valid" do
          expect(product).to be_valid
        end
      end

      context "available_on is a date earlier than discontinue_on" do
        before { product.discontinue_on = 5.days.ago }

        context "is not valid" do
          before { product.valid? }

          it { expect(product).not_to be_valid }
          it { expect(product.errors[:discontinue_on]).to include(I18n.t(:invalid_date_range, scope: 'activerecord.errors.models.spree/product.attributes.discontinue_on')) }
        end
      end

      context "available_on and discontinue_on are nil" do
        before do
          product.discontinue_on = nil
          product.available_on = nil
        end

        it "is valid" do
          expect(product).to be_valid
        end
      end
    end

    context "hard deletion" do
      it "doesnt raise ActiveRecordError error" do
        expect { product.really_destroy! }.to_not raise_error
      end
    end

    context 'history' do
      before(:each) do
        @product = create(:product)
      end

      it 'should keep the history when the product is destroyed' do
        @product.destroy

        expect(@product.slugs.with_deleted).to_not be_empty
      end

      it 'should update the history when the product is restored' do
        @product.destroy

        @product.restore(recursive: true)

        latest_slug = @product.slugs.find_by slug: @product.slug
        expect(latest_slug).to_not be_nil
      end
    end
  end

  context "properties" do
    let(:product) { create(:product) }

    it "should properly assign properties" do
      product.set_property('the_prop', 'value1')
      expect(product.property('the_prop')).to eq('value1')

      product.set_property('the_prop', 'value2')
      expect(product.property('the_prop')).to eq('value2')
    end

    it "should not create duplicate properties when set_property is called" do
      expect {
        product.set_property('the_prop', 'value2')
        product.save
        product.reload
      }.not_to change(product.properties, :length)

      expect {
        product.set_property('the_prop_new', 'value')
        product.save
        product.reload
        expect(product.property('the_prop_new')).to eq('value')
      }.to change { product.properties.length }.by(1)
    end

    context 'optional property_presentation' do
      subject { Spree::Property.where(name: 'foo').first.presentation }
      let(:name) { 'foo' }
      let(:presentation) { 'baz' }

      describe 'is not used' do
        before { product.set_property(name, 'bar') }
        it { is_expected.to eq name }
      end

      describe 'is used' do
        before { product.set_property(name, 'bar', presentation) }
        it { is_expected.to eq presentation }
      end
    end

    # Regression test for #2455
    it "should not overwrite properties' presentation names" do
      Spree::Property.where(name: 'foo').first_or_create!(presentation: "Foo's Presentation Name")
      product.set_property('foo', 'value1')
      product.set_property('bar', 'value2')
      expect(Spree::Property.where(name: 'foo').first.presentation).to eq("Foo's Presentation Name")
      expect(Spree::Property.where(name: 'bar').first.presentation).to eq("bar")
    end

    # Regression test for #4416
    context "#possible_promotions" do
      let!(:possible_promotion) { create(:promotion, advertise: true, starts_at: 1.day.ago) }
      let!(:unadvertised_promotion) { create(:promotion, advertise: false, starts_at: 1.day.ago) }
      let!(:inactive_promotion) { create(:promotion, advertise: true, starts_at: 1.day.since) }

      before do
        product.promotion_rules.create!(promotion: possible_promotion)
        product.promotion_rules.create!(promotion: unadvertised_promotion)
        product.promotion_rules.create!(promotion: inactive_promotion)
      end

      it "lists the promotion as a possible promotion" do
        expect(product.possible_promotions).to include(possible_promotion)
        expect(product.possible_promotions).to_not include(unadvertised_promotion)
        expect(product.possible_promotions).to_not include(inactive_promotion)
      end
    end
  end

  context '#create' do
    let!(:prototype) { create(:prototype) }
    let!(:product) { Spree::Product.new(name: "Foo", price: 1.99, shipping_category_id: create(:shipping_category).id) }

    before { product.prototype_id = prototype.id }

    context "when prototype is supplied" do
      it "should create properties based on the prototype" do
        product.save
        expect(product.properties.count).to eq(1)
      end
    end

    context "when prototype with option types is supplied" do
      def build_option_type_with_values(name, values)
        values.each_with_object(create :option_type, name: name) do |val, ot|
          ot.option_values.create(name: val.downcase, presentation: val)
        end
      end

      let(:prototype) do
        size = build_option_type_with_values("size", %w(Small Medium Large))
        create(:prototype, name: "Size", option_types: [ size ])
      end

      let(:option_values_hash) do
        hash = {}
        prototype.option_types.each do |i|
          hash[i.id.to_s] = i.option_value_ids
        end
        hash
      end

      it "should create option types based on the prototype" do
        product.save
        expect(product.option_type_ids.length).to eq(1)
        expect(product.option_type_ids).to eq(prototype.option_type_ids)
      end

      it "should create product option types based on the prototype" do
        product.save
        expect(product.product_option_types.pluck(:option_type_id)).to eq(prototype.option_type_ids)
      end

      it "should create variants from an option values hash with one option type" do
        product.option_values_hash = option_values_hash
        product.save
        expect(product.variants.length).to eq(3)
      end

      it "should still create variants when option_values_hash is given but prototype id is nil" do
        product.option_values_hash = option_values_hash
        product.prototype_id = nil
        product.save
        product.reload
        expect(product.option_type_ids.length).to eq(1)
        expect(product.option_type_ids).to eq(prototype.option_type_ids)
        expect(product.variants.length).to eq(3)
      end

      it "should create variants from an option values hash with multiple option types" do
        color = build_option_type_with_values("color", %w(Red Green Blue))
        logo  = build_option_type_with_values("logo", %w(Ruby Rails Nginx))
        option_values_hash[color.id.to_s] = color.option_value_ids
        option_values_hash[logo.id.to_s] = logo.option_value_ids
        product.option_values_hash = option_values_hash
        product.save
        product.reload
        expect(product.option_type_ids.length).to eq(3)
        expect(product.variants.length).to eq(27)
      end
    end
  end

  context "#images" do
    let(:product) { create(:product) }
    let(:image) { File.open(File.expand_path('../../../fixtures/thinking-cat.jpg', __FILE__)) }
    let(:params) { {viewable_id: product.master.id, viewable_type: 'Spree::Variant', attachment: image, alt: "position 2", position: 2} }

    before do
      Spree::Image.create(params)
      Spree::Image.create(params.merge({alt: "position 1", position: 1}))
      Spree::Image.create(params.merge({viewable_type: 'ThirdParty::Extension', alt: "position 1", position: 2}))
    end

    it "only looks for variant images" do
      expect(product.images.size).to eq(2)
    end

    it "should be sorted by position" do
      expect(product.images.pluck(:alt)).to eq(["position 1", "position 2"])
    end
  end

  # Regression tests for #2352
  context "classifications and taxons" do
    it "is joined through classifications" do
      reflection = Spree::Product.reflect_on_association(:taxons)
      expect(reflection.options[:through]).to eq(:classifications)
    end

    it "will delete all classifications" do
      reflection = Spree::Product.reflect_on_association(:classifications)
      expect(reflection.options[:dependent]).to eq(:delete_all)
    end
  end

  context '#total_on_hand' do
    let(:product) { create(:product) }

    it 'should be infinite if track_inventory_levels is false' do
      Spree::Config[:track_inventory_levels] = false
      expect(build(:product, variants_including_master: [build(:master_variant)]).total_on_hand).to eql(Float::INFINITY)
    end

    it 'should be infinite if variant is on demand' do
      Spree::Config[:track_inventory_levels] = true
      expect(build(:product, variants_including_master: [build(:on_demand_master_variant)]).total_on_hand).to eql(Float::INFINITY)
    end

    it 'should return sum of stock items count_on_hand' do
      product.stock_items.first.set_count_on_hand 5
      product.variants_including_master.reload # force load association
      expect(product.total_on_hand).to eql(5)
    end

    it 'should return sum of stock items count_on_hand when variants_including_master is not loaded' do
      product.stock_items.first.set_count_on_hand 5
      expect(product.reload.total_on_hand).to eql(5)
    end
  end

  # Regression spec for https://github.com/spree/spree/issues/5588
  context '#validate_master when duplicate SKUs entered' do
    let!(:first_product) { create(:product, sku: 'a-sku') }
    let(:second_product) { build(:product, sku: 'a-sku') }

    subject { second_product }
    it { is_expected.to be_invalid }
  end

  it "initializes a master variant when building a product" do
    product = Spree::Product.new
    expect(product.master.is_master).to be true
  end

  context "#discontinue!" do
    let(:product) { create(:product, sku: 'a-sku') }

    it "sets the discontinued" do
      product.discontinue!
      product.reload
      expect(product.discontinued?).to be(true)
    end

    it "changes updated_at" do
      Timecop.scale(1000) do
        expect { product.discontinue! }.to change { product.updated_at }
      end
    end
  end

  context "#discontinued?" do
    let(:product_live) { build(:product, sku: "a-sku") }
    it "should be false" do
      expect(product_live.discontinued?).to be(false)
    end

    let(:product_discontinued) { build(:product, sku: "a-sku", discontinue_on: Time.now - 1.day)  }
    it "should be true" do
      expect(product_discontinued.discontinued?).to be(true)
    end
  end

  context "acts_as_taggable" do
    let(:product) { create(:product) }

    it "should add tags" do
      product.tag_list.add("awesome")
      expect(product.tag_list).to include("awesome")
    end

    it "should remove tags" do
      product.tag_list.remove("awesome")
      expect(product.tag_list).to_not include("awesome")
    end
  end

  context "#brand" do
    let(:taxonomy) { create(:taxonomy, name: I18n.t('spree.taxonomy_brands_name')) }
    let(:product) { create(:product, taxons: [taxonomy.taxons.first]) }

    it 'should fetch Brand Taxon' do
      expect(product.brand).to eql(taxonomy.taxons.first)
    end
  end

  context "#category" do
    let(:taxonomy) { create(:taxonomy, name: I18n.t('spree.taxonomy_categories_name')) }
    let(:product) { create(:product, taxons: [taxonomy.taxons.first]) }

    it 'should fetch Category Taxon' do
      expect(product.category).to eql(taxonomy.taxons.first)
    end
  end

  describe '#ensure_no_line_items' do
    let(:product) { create(:product) }
    let!(:line_item) { create(:line_item, variant: product.master) }

    it 'should add error on product destroy' do
      expect(product.destroy).to eq false
      expect(product.errors[:base]).to include Spree.t(:cannot_destroy_if_attached_to_line_items)
    end
  end
end
