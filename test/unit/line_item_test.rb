require 'test_helper'

class LineItemTest < Test::Unit::TestCase
  context "LineItem instance" do
    setup { @line_item = Factory.build(:line_item, :quantity => 2, :price => 15.00) }
    should "be valid" do
      assert @line_item.valid?
    end
    should_validate_numericality_of :price

    context "with non-numeric quantity" do
      setup { @line_item.quantity = "foo" }
      should "should be invalid" do
        assert !@line_item.valid?
      end
    end
    
    context "increment_quantity call" do
      setup { @line_item.increment_quantity }
      should_change "@line_item.quantity", :by => 1
      #assert_equal 2, @line_item.quantity       
    end
    
    should "return the correct total" do
      assert_in_delta @line_item.total, 30.00, 0.00001
    end        
  end
  
  context "when variant is out of stock" do
    setup { @line_item = Factory.build(:line_item, :quantity => 4) }

    context "when backordering is allowed" do
      setup { Spree::Config.set(:allow_backorders => true) }
      should "not be valid" do
        assert @line_item.valid?
      end
    end

    context "when backordering is disallowed" do
      setup { Spree::Config.set(:allow_backorders => false) }    
      teardown { Spree::Config.set(:allow_backorders => true) }
      should "disallow creation for an out of stock variant" do
        assert !@line_item.valid?
      end
    end
  end

  context "when variant is in stock but insufficient to cover the requested quantity" do
    setup do
      @line_item = Factory.build(:line_item, :variant => Factory(:variant, :on_hand => "1"), :quantity => 2)
    end

    context "when backordering is allowed" do
      setup do
        Spree::Config.set(:allow_backorders => true)
      end
      should "not be valid" do
        assert @line_item.valid?
      end
    end

    context "when backordering is disallowed" do
      setup { Spree::Config.set(:allow_backorders => false) }
      teardown { Spree::Config.set(:allow_backorders => true) }
      should "disallow creation for an out of stock variant" do
        assert !@line_item.valid?
      end
    end
  end

end