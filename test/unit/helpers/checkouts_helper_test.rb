require 'test_helper'

class CheckoutsHelperTest < ActionView::TestCase
  context "with current_user" do
    setup do
      self.stub!(:current_user, :return => User.new)
    end
    context "checkout_steps" do
      setup { @steps = checkout_steps }
      should "not contain the registration step" do
        assert_does_not_contain(@steps, 'registration')
      end
    end
  end
  context "with no current_user" do
    setup do 
      self.stub!(:current_user, :return => nil)
    end
    context "checkout_steps" do
      setup { @steps = checkout_steps }
      should "contain the registration step" do
        assert_contains(@steps, 'registration')
      end
    end
  end
end
