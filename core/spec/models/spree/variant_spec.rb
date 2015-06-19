# encoding: utf-8

require 'spec_helper'

describe Spree::Variant, :type => :model do
  let!(:variant) { create(:variant) }

  it_behaves_like 'default_price'

  context 'sorting' do
    it 'responds to set_list_position' do
      expect(variant.respond_to?(:set_list_position)).to eq(true)
    end
  end

  context "validations" do
    it "should validate price is greater than 0" do
      variant.price = -1
      expect(variant).to be_invalid
    end

    it "should validate price is 0" do
      variant.price = 0
      expect(variant).to be_valid
    end
  end

  context "after create" do
    let!(:product) { create(:product) }

    it "propagate to stock items" do
      expect_any_instance_of(Spree::StockLocation).to receive(:propagate_variant)
      product.variants.create(:name => "Foobar")
    end

    context "stock location has disable propagate all variants" do
      before { Spree::StockLocation.update_all propagate_all_variants: false }

      it "propagate to stock items" do
        expect_any_instance_of(Spree::StockLocation).not_to receive(:propagate_variant)
        product.variants.create(:name => "Foobar")
      end
    end

    describe 'mark_master_out_of_stock' do
      before do
        product.master.stock_items.first.set_count_on_hand(5)
      end
      context 'when product is created without variants but with stock' do
        it { expect(product.master).to be_in_stock }
      end

      context 'when a variant is created' do
        before(:each) do
          product.variants.create!(:name => 'any-name')
        end

        it { expect(product.master).to_not be_in_stock }
      end
    end
  end

  context "product has other variants" do
    describe "option value accessors" do
      before {
        @multi_variant = FactoryGirl.create :variant, :product => variant.product
        variant.product.reload
      }

      let(:multi_variant) { @multi_variant }

      it "should set option value" do
        expect(multi_variant.option_value('media_type')).to be_nil

        multi_variant.set_option_value('media_type', 'DVD')
        expect(multi_variant.option_value('media_type')).to eql 'DVD'

        multi_variant.set_option_value('media_type', 'CD')
        expect(multi_variant.option_value('media_type')).to eql 'CD'
      end

      it "should not duplicate associated option values when set multiple times" do
        multi_variant.set_option_value('media_type', 'CD')

        expect {
         multi_variant.set_option_value('media_type', 'DVD')
        }.to_not change(multi_variant.option_values, :count)

        expect {
          multi_variant.set_option_value('coolness_type', 'awesome')
        }.to change(multi_variant.option_values, :count).by(1)
      end
    end

    context "product has other variants" do
      describe "option value accessors" do
        before {
          @multi_variant = create(:variant, :product => variant.product)
          variant.product.reload
        }

        let(:multi_variant) { @multi_variant }

        it "should set option value" do
          expect(multi_variant.option_value('media_type')).to be_nil

          multi_variant.set_option_value('media_type', 'DVD')
          expect(multi_variant.option_value('media_type')).to eql 'DVD'

          multi_variant.set_option_value('media_type', 'CD')
          expect(multi_variant.option_value('media_type')).to eql 'CD'
        end

        it "should not duplicate associated option values when set multiple times" do
          multi_variant.set_option_value('media_type', 'CD')

          expect {
           multi_variant.set_option_value('media_type', 'DVD')
          }.to_not change(multi_variant.option_values, :count)

          expect {
            multi_variant.set_option_value('coolness_type', 'awesome')
          }.to change(multi_variant.option_values, :count).by(1)
        end
      end
    end
  end

  context "#cost_price=" do
    it "should use LocalizedNumber.parse" do
      expect(Spree::LocalizedNumber).to receive(:parse).with('1,599.99')
      subject.cost_price = '1,599.99'
    end
  end

  context "#price=" do
    it "should use LocalizedNumber.parse" do
      expect(Spree::LocalizedNumber).to receive(:parse).with('1,599.99')
      subject.price = '1,599.99'
    end
  end

  context "#weight=" do
    it "should use LocalizedNumber.parse" do
      expect(Spree::LocalizedNumber).to receive(:parse).with('1,599.99')
      subject.weight = '1,599.99'
    end
  end

  context "#currency" do
    it "returns the globally configured currency" do
      expect(variant.currency).to eql "USD"
    end
  end

  context "#display_amount" do
    it "returns a Spree::Money" do
      variant.price = 21.22
      expect(variant.display_amount.to_s).to eql "$21.22"
    end
  end

  context "#cost_currency" do
    context "when cost currency is nil" do
      before { variant.cost_currency = nil }
      it "populates cost currency with the default value on save" do
        variant.save!
        expect(variant.cost_currency).to eql "USD"
      end
    end
  end

  describe '.price_in' do
    before do
      variant.prices << create(:price, :variant => variant, :currency => "EUR", :amount => 33.33)
    end
    subject { variant.price_in(currency).display_amount }

    context "when currency is not specified" do
      let(:currency) { nil }

      it "returns 0" do
        expect(subject.to_s).to eql "$0.00"
      end
    end

    context "when currency is EUR" do
      let(:currency) { 'EUR' }

      it "returns the value in the EUR" do
        expect(subject.to_s).to eql "€33.33"
      end
    end

    context "when currency is USD" do
      let(:currency) { 'USD' }

      it "returns the value in the USD" do
        expect(subject.to_s).to eql "$19.99"
      end
    end
  end

  describe '.amount_in' do
    before do
      variant.prices << create(:price, :variant => variant, :currency => "EUR", :amount => 33.33)
    end

    subject { variant.amount_in(currency) }

    context "when currency is not specified" do
      let(:currency) { nil }

      it "returns nil" do
        expect(subject).to be_nil
      end
    end

    context "when currency is EUR" do
      let(:currency) { 'EUR' }

      it "returns the value in the EUR" do
        expect(subject).to eql 33.33
      end
    end

    context "when currency is USD" do
      let(:currency) { 'USD' }

      it "returns the value in the USD" do
        expect(subject).to eql 19.99
      end
    end
  end

  # Regression test for #2432
  describe 'options_text' do
    let!(:variant) { create(:variant, option_values: []) }
    let!(:master) { create(:master_variant) }

    before do
      # Order bar than foo
      variant.option_values << create(:option_value, {name: 'Foo', presentation: 'Foo', option_type: create(:option_type, position: 2, name: 'Foo Type', presentation: 'Foo Type')})
      variant.option_values << create(:option_value, {name: 'Bar', presentation: 'Bar', option_type: create(:option_type, position: 1, name: 'Bar Type', presentation: 'Bar Type')})
    end

    it 'should order by bar than foo' do
      expect(variant.options_text).to eql 'Bar Type: Bar, Foo Type: Foo'
    end

  end

  describe 'exchange_name' do
    let!(:variant) { create(:variant, option_values: []) }
    let!(:master) { create(:master_variant) }

    before do
      variant.option_values << create(:option_value, {
                                                     name: 'Foo',
                                                     presentation: 'Foo',
                                                     option_type: create(:option_type, position: 2, name: 'Foo Type', presentation: 'Foo Type')
                                                   })
    end

    context 'master variant' do
      it 'should return name' do
        expect(master.exchange_name).to eql master.name
      end
    end

    context 'variant' do
      it 'should return options text' do
        expect(variant.exchange_name).to eql 'Foo Type: Foo'
      end
    end

  end

  describe 'exchange_name' do
    let!(:variant) { create(:variant, option_values: []) }
    let!(:master) { create(:master_variant) }

    before do
      variant.option_values << create(:option_value, {
                                                     name: 'Foo',
                                                     presentation: 'Foo',
                                                     option_type: create(:option_type, position: 2, name: 'Foo Type', presentation: 'Foo Type')
                                                   })
    end

    context 'master variant' do
      it 'should return name' do
        expect(master.exchange_name).to eql master.name
      end
    end

    context 'variant' do
      it 'should return options text' do
        expect(variant.exchange_name).to eql 'Foo Type: Foo'
      end
    end

  end

  describe 'descriptive_name' do
    let!(:variant) { create(:variant, option_values: []) }
    let!(:master) { create(:master_variant) }

    before do
      variant.option_values << create(:option_value, {
                                                     name: 'Foo',
                                                     presentation: 'Foo',
                                                     option_type: create(:option_type, position: 2, name: 'Foo Type', presentation: 'Foo Type')
                                                   })
    end

    context 'master variant' do
      it 'should return name with Master identifier' do
        expect(master.descriptive_name).to eql master.name + ' - Master'
      end
    end

    context 'variant' do
      it 'should return options text with name' do
        expect(variant.descriptive_name).to eql variant.name + ' - Foo Type: Foo'
      end
    end

  end

  # Regression test for #2744
  describe "set_position" do
    it "sets variant position after creation" do
      variant = create(:variant)
      expect(variant.position).to_not be_nil
    end
  end

  describe '#in_stock?' do
    before do
      Spree::Config.track_inventory_levels = true
    end

    context 'when stock_items are not backorderable' do
      before do
        allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: false)
      end

      context 'when stock_items in stock' do
        before do
          variant.stock_items.first.update_column(:count_on_hand, 10)
        end

        it 'returns true if stock_items in stock' do
          expect(variant.in_stock?).to be true
        end
      end

      context 'when stock_items out of stock' do
        before do
          allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: false)
          allow_any_instance_of(Spree::StockItem).to receive_messages(count_on_hand: 0)
        end

        it 'return false if stock_items out of stock' do
          expect(variant.in_stock?).to be false
        end
      end
    end

    describe "#can_supply?" do
      it "calls out to quantifier" do
        expect(Spree::Stock::Quantifier).to receive(:new).and_return(quantifier = double)
        expect(quantifier).to receive(:can_supply?).with(10)
        variant.can_supply?(10)
      end
    end

    context 'when stock_items are backorderable' do
      before do
        allow_any_instance_of(Spree::StockItem).to receive_messages(backorderable: true)
      end

      context 'when stock_items out of stock' do
        before do
          allow_any_instance_of(Spree::StockItem).to receive_messages(count_on_hand: 0)
        end

        it 'in_stock? returns false' do
          expect(variant.in_stock?).to be false
        end

        it 'can_supply? return true' do
          expect(variant.can_supply?).to be true
        end
      end
    end
  end

  describe '#is_backorderable' do
    let(:variant) { build(:variant) }
    subject { variant.is_backorderable? }

    it 'should invoke Spree::Stock::Quantifier' do
      expect_any_instance_of(Spree::Stock::Quantifier).to receive(:backorderable?) { true }
      subject
    end
  end

  describe '#total_on_hand' do
    it 'should be infinite if track_inventory_levels is false' do
      Spree::Config[:track_inventory_levels] = false
      expect(build(:variant).total_on_hand).to eql(Float::INFINITY)
    end

    it 'should match quantifier total_on_hand' do
      variant = build(:variant)
      expect(variant.total_on_hand).to eq(Spree::Stock::Quantifier.new(variant).total_on_hand)
    end
  end

  describe '#tax_category' do
    context 'when tax_category is nil' do
      let(:product) { build(:product) }
      let(:variant) { build(:variant, product: product, tax_category_id: nil) }
      it 'returns the parent products tax_category' do
        expect(variant.tax_category).to eq(product.tax_category)
      end
    end

    context 'when tax_category is set' do
      let(:tax_category) { create(:tax_category) }
      let(:variant) { build(:variant, tax_category: tax_category) }
      it 'returns the tax_category set on itself' do
        expect(variant.tax_category).to eq(tax_category)
      end
    end
  end

  describe "touching" do
    it "updates a product" do
      variant.product.update_column(:updated_at, 1.day.ago)
      variant.touch
      expect(variant.product.reload.updated_at).to be_within(3.seconds).of(Time.now)
    end

    it "clears the in_stock cache key" do
      expect(Rails.cache).to receive(:delete).with(variant.send(:in_stock_cache_key))
      variant.touch
    end
  end

  describe "#should_track_inventory?" do

    it 'should not track inventory when global setting is off' do
      Spree::Config[:track_inventory_levels] = false

      expect(build(:variant).should_track_inventory?).to eq(false)
    end

    it 'should not track inventory when variant is turned off' do
      Spree::Config[:track_inventory_levels] = true

      expect(build(:on_demand_variant).should_track_inventory?).to eq(false)
    end

    it 'should track inventory when global and variant are on' do
      Spree::Config[:track_inventory_levels] = true

      expect(build(:variant).should_track_inventory?).to eq(true)
    end
  end

  describe "deleted_at scope" do
    before { variant.destroy && variant.reload }
    it "should have a price if deleted" do
      variant.price = 10
      expect(variant.price).to eq(10)
    end
  end

  describe "stock movements" do
    let!(:movement) { create(:stock_movement, stock_item: variant.stock_items.first) }

    it "builds out collection just fine through stock items" do
      expect(variant.stock_movements.to_a).not_to be_empty
    end
  end

  describe "in_stock scope" do
    it "returns all in stock variants" do
      in_stock_variant = create(:variant)
      out_of_stock_variant = create(:variant)

      in_stock_variant.stock_items.first.update_column(:count_on_hand, 10)

      expect(Spree::Variant.in_stock).to eq [in_stock_variant]
    end
  end

  context "#volume" do
    let(:variant_zero_width) { create(:variant, width: 0) }
    let(:variant) { create(:variant) }

    it "it is zero if any dimension parameter is zero" do
      expect(variant_zero_width.volume).to eq 0
    end

    it "return the volume if the dimension parameters are different of zero" do
      volume_expected = variant.width * variant.depth * variant.height
      expect(variant.volume).to eq (volume_expected)
    end
  end

  context "#dimension" do
    let(:variant) { create(:variant) }

    it "return the dimension if the dimension parameters are different of zero" do
      dimension_expected = variant.width + variant.depth + variant.height
      expect(variant.dimension).to eq (dimension_expected)
    end
  end
end
