require 'spec_helper'

describe PromotionRule do
  before(:all) do
    class MyRule < PromotionRule
      def self.unregister
        @@rule_classes.delete(self)
      end
    end
  end

  after do
    MyRule.unregister
  end

  it "should allow registering rules" do
    PromotionRule.rule_classes.should_not include(MyRule)
    MyRule.rule_classes.should_not include(MyRule)

    MyRule.register

    PromotionRule.rule_classes.should include(MyRule)
    MyRule.rule_classes.should include(MyRule)
  end

  it "should allow to get rule class names" do
    MyRule.register

    MyRule.rule_class_names.should include("MyRule")
  end

  it "should force developer to implement eligible? method" do
    lambda { MyRule.new.eligible? }.should raise_error
  end

end
