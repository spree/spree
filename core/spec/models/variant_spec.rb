require 'spec_helper'

describe Spree::Variant do
  let!(:variant) { create(:variant, :count_on_hand => 95) }

  before(:each) do
    reset_spree_preferences
  end

  context "validations" do
    it "should validate price is greater than 0" do
      variant.price = -1
      variant.should be_invalid
    end

    it "should validate price is 0" do
      variant.price = 0
      variant.should be_valid
    end
  end

  # Regression test for #1778
  it "recalculates product's count_on_hand when saved" do
    Spree::Config[:track_inventory_levels] = true
    variant.stub :is_master? => true
    variant.product.should_receive(:on_hand).and_return(3)
    variant.product.should_receive(:update_column).with(:count_on_hand, 3)
    variant.run_callbacks(:save)
  end

  it "lock_version should prevent stale updates" do
    copy = Spree::Variant.find(variant.id)

    copy.count_on_hand = 200
    copy.save!

    variant.count_on_hand = 100
    expect { variant.save }.to raise_error ActiveRecord::StaleObjectError

    variant.reload.count_on_hand.should == 200
    variant.count_on_hand = 100
    variant.save

    variant.reload.count_on_hand.should == 100
  end

  context "on_hand=" do
    before { variant.stub(:inventory_units => mock('inventory-units')) }

    context "when :track_inventory_levels is true" do
      before { Spree::Config.set :track_inventory_levels => true }

      context "and count is increased" do
        before { variant.inventory_units.stub(:with_state).and_return([]) }
        let(:inventory_unit) { mock_model(Spree::InventoryUnit, :state => "backordered") }

        it "should change count_on_hand to given value" do
          variant.on_hand = 100
          variant.count_on_hand.should == 100
        end

        it "should check for backordered units" do
          variant.save!
          variant.inventory_units.should_receive(:with_state).with("backordered")
          variant.on_hand = 100
          variant.save!
        end

        it "should fill 1 backorder when count_on_hand is zero" do
          variant.count_on_hand = 0
          variant.save!
          variant.inventory_units.stub(:with_state).and_return([inventory_unit])
          inventory_unit.should_receive(:fill_backorder)
          variant.on_hand = 100
          variant.save!
          variant.count_on_hand.should == 99
        end

        it "should fill multiple backorders when count_on_hand is negative" do
          variant.count_on_hand = -5
          variant.save!
          variant.inventory_units.stub(:with_state).and_return(Array.new(5, inventory_unit))
          inventory_unit.should_receive(:fill_backorder).exactly(5).times
          variant.on_hand = 100
          variant.save!
          variant.count_on_hand.should == 95
        end

        it "should keep count_on_hand negative when count is not enough to fill backorders" do
          variant.count_on_hand = -10
          variant.save!
          variant.inventory_units.stub(:with_state).and_return(Array.new(10, inventory_unit))
          inventory_unit.should_receive(:fill_backorder).exactly(5).times
          variant.on_hand = 5
          variant.save!
          variant.count_on_hand.should == -5
        end

      end

      context "and count is negative" do
        before { variant.inventory_units.stub(:with_state).and_return([]) }

        it "should change count_on_hand to given value" do
          variant.on_hand = 10
          variant.count_on_hand.should == 10
        end

        it "should not check for backordered units" do
          variant.inventory_units.should_not_receive(:with_state)
          variant.on_hand = 10
        end

      end

    end

    context "when :track_inventory_levels is false" do
      before { Spree::Config.set :track_inventory_levels => false }

      it "should raise an exception" do
        lambda { variant.on_hand = 100 }.should raise_error
      end

    end

  end

  context "on_hand" do
    context "when :track_inventory_levels is true" do
      before { Spree::Config.set :track_inventory_levels => true }

      it "should return count_on_hand" do
        variant.on_hand.should == variant.count_on_hand
      end
    end

    context "when :track_inventory_levels is false" do
      before { Spree::Config.set :track_inventory_levels => false }

      it "should return nil" do
        variant.on_hand.should eql(1.0/0) # Infinity
      end

    end

  end

  context "in_stock?" do
    context "when :track_inventory_levels is true" do
      before { Spree::Config.set :track_inventory_levels => true }

      it "should be true when count_on_hand is positive" do
        variant.in_stock?.should be_true
      end

      it "should be false when count_on_hand is zero" do
        variant.stub(:count_on_hand => 0)
        variant.in_stock?.should be_false
      end

      it "should be false when count_on_hand is negative" do
        variant.stub(:count_on_hand => -10)
        variant.in_stock?.should be_false
      end
    end

    context "when :track_inventory_levels is false" do
      before { Spree::Config.set :track_inventory_levels => false }

      it "should be true" do
        variant.in_stock?.should be_true
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
          multi_variant.option_value('media_type').should be_nil

          multi_variant.set_option_value('media_type', 'DVD')
          multi_variant.option_value('media_type').should == 'DVD'

          multi_variant.set_option_value('media_type', 'CD')
          multi_variant.option_value('media_type').should == 'CD'
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

  context "price parsing" do
    before(:each) do
      I18n.locale = I18n.default_locale
      I18n.backend.store_translations(:de, { :number => { :currency => { :format => { :delimiter => '.', :separator => ',' } } } })
    end

    after do
      I18n.locale = I18n.default_locale
    end

    context "price=" do
      context "with decimal point" do
        it "captures the proper amount for a formatted price" do
          variant.price = '1,599.99'
          variant.price.should == 1599.99
        end
      end

      context "with decimal comma" do
        it "captures the proper amount for a formatted price" do
          I18n.locale = :de
          variant.price = '1.599,99'
          variant.price.should == 1599.99
        end
      end

      context "with a numeric price" do
        it "uses the price as is" do
          I18n.locale = :de
          variant.price = 1599.99
          variant.price.should == 1599.99
        end
      end
    end

    context "cost_price=" do
      context "with decimal point" do
        it "captures the proper amount for a formatted price" do
          variant.cost_price = '1,599.99'
          variant.cost_price.should == 1599.99
        end
      end

      context "with decimal comma" do
        it "captures the proper amount for a formatted price" do
          I18n.locale = :de
          variant.cost_price = '1.599,99'
          variant.cost_price.should == 1599.99
        end
      end

      context "with a numeric price" do
        it "uses the price as is" do
          I18n.locale = :de
          variant.cost_price = 1599.99
          variant.cost_price.should == 1599.99
        end
      end
    end
  end

  context "#currency" do
    it "returns the globally configured currency" do
      variant.currency.should == "USD"
    end
  end

  context "#display_amount" do
    it "retuns a Spree::Money" do
      variant.price = 21.22
      variant.display_amount.should == Spree::Money.new(21.22)
    end
  end
end
