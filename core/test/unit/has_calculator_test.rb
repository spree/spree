require 'test_helper'

# class TestModel < ActiveRecord::Base
#   has_calculator
# end  

class HasCalculatorTest < ActiveSupport::TestCase
  context "has_calculator" do
    setup do         
      @object = Promotion.new
    end

    should "add calculator as has_one association" do
      assert Promotion.reflect_on_all_associations(:has_one).map(&:name).include?(:calculator)
    end

    # should "add default calculator" do
    #   assert @shipment.calculator
    # end

  end
end
