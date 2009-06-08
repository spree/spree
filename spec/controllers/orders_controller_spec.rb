require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe OrdersController do
  before(:each) do
    @variant = mock_model(Variant, :price => 10, :on_hand => 50)
    Variant.stub!(:find, :return => @variant)
    @order = Order.create
    @token = "TOKEN123"
    @order.token = @token
    @order.save
  end

  describe "create" do
    it "should add the variant to the order" do
      controller.stub!(:object, :return => @order)
      @order.should_receive(:add_variant).with(@variant, 2)
      post :create, :variants => {"345" => 2}
    end

    it "should not set the state" do
      @order.should_not_receive(:state=)
      post :create, :id => @order.number, :quantities => {456 => "123=1"}, :order => {:state => "paid"}
    end   
  end
  
  describe "update" do
    %w{ship_amount tax_amount item_total total user number ip_address checkout_complete state}.each do |attribute|
      it "should not set #{attribute} with mass assignment" do
        #@order.send(attribute).should_not == "naughty"
        @order.should_not_receive("#{attribute}=".to_sym).with("naughty")
        put :update, "id" => @order.number, "order" => {attribute => "naughty"}
      end
    end
  end
end
