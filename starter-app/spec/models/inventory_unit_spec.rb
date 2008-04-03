require File.dirname(__FILE__) + '/../spec_helper.rb'

describe InventoryUnit do
  
  before(:each) do
    @order = mock_model(Order)
  end
  
  it "should mark the correct number of inventory units as SOLD" do
    line_item = mock_model(LineItem)
    variant = mock_model(Variant)
    line_item.stub!(:variant).and_return(variant)
    @order.stub!(:line_items).and_return([line_item])
    
    # TODO - finish this test
  end
  
end