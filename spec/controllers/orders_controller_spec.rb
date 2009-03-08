require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe OrdersController do
  before(:each) do
    Variant.stub!(:find).with(any_args).and_return(@variant = mock_model(Variant, :price => 10, :on_hand => 50))
    @order = Order.new
    @order.stub!(:number).and_return("R100")
    controller.stub!(:find_order).and_return(@order)
  end

  describe "create" do
    it "should add the variant to the order" do
      @order.should_receive(:add_variant).with(@variant,2)
	post :create, :id => "345", :quantities => {456 => "123=2"}
    end
  
    it "should not set the state" do
      @order.should_not_receive(:state=)
      post :create, :id => "345", :quantities => {456 => "123=1"}, :order => {:state => "paid"}
    end    
  end
  
  describe "update" do
    %w{ship_amount tax_amount item_total total user number ip_address checkout_complete state}.each do |attribute|
      it "should not set #{attribute} with mass assignment" do
        #@order.send(attribute).should_not == "naughty"
        @order.should_not_receive("#{attribute}=".to_sym).with("naughty")
        put :update, "id" => "123", "order" => {attribute => "naughty"}
      end
    end
  end
end
