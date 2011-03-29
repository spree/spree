require 'spec_helper'

describe PromotionAction do
  before(:all) do
    class MyAction < PromotionAction
      def self.unregister
        @@registered_classes.delete(self)
      end
    end
  end

  after do
    MyAction.unregister
  end

  it "should force developer to implement 'perform' method" do
    lambda { MyAction.new.perform }.should raise_error
  end

end

