require File.dirname(__FILE__) + '/../spec_helper.rb'

describe Order do
  before(:each) do
    @variant = Variant.new(:id => "1234", :price => 7.99)
    @inventory_unit = mock_model(InventoryUnit, :null_object => true)
    @creditcard_payment = mock_model(CreditcardPayment, :null_object => true)
    @user = mock_model(User, :email => "foo@exampl.com")

    @order = Order.new
    @order.checkout_complete = true
    @order.creditcard_payments = [@creditcard_payment]
    @order.number = '#TEST1010'
    @order.user =  @user

    @order.stub!(:save => true, :inventory_units => [@inventory_unit])
    @line_item =  LineItem.new(:variant => @variant, :quantity => 1, :price => 7.99)
    @order.line_items << @line_item
    InventoryUnit.stub!(:retrieve_on_hand).with(@variant, 1).and_return [@inventory_unit]
    OrderMailer.stub!(:deliver_confirm).with(any_args)   
    OrderMailer.stub!(:deliver_cancel).with(any_args)    

  end

  describe "create" do
    it "should generate an order number" do
      order = Order.create
      order.number.should_not be_nil
    end
    it "should generate a token" do
      order = Order.create
      order.token.should_not be_nil 
    end
  end
  
  describe "next" do
    describe "from creditcard_payment" do
      before(:each) do
        @order.state = 'creditcard'
      end
      it "should transition to new" do
        @order.next
        @order.state.should == "new"
      end
      it "should mark inventory as sold" do
        @inventory_unit.should_receive(:sell!)
        @order.next
      end
      it "should send a confirmation email" do
        OrderMailer.should_receive(:deliver_confirm).with(@order)
        @order.next
      end
    end
  end
    
  describe "cancel" do
    it "should mark inventory as on_hand" do
      @order.state = "captured"
      @inventory_unit.stub!(:state).and_return('sold')
      @inventory_unit.should_receive(:restock!)
      @order.cancel
    end
    it "should send a cancellation email" do
      OrderMailer.should_receive(:deliver_cancel).with(@order)
      @order.cancel
    end                        
    %w{in_progress creditcard}.each do |state|
      it "should be available in the #{state} state" do
        @order.state = state
        @order.checkout_complete = false
        @order.can_cancel?.should be_true
      end
    end
  end
  
  describe "return" do
    it "should mark inventory as on_hand" do
      @order.state = "shipped"
      @inventory_unit.stub!(:state).and_return('shipped')
      @inventory_unit.should_receive(:restock!)
      @order.return
    end
  end
  
  describe "add_variant" do
    it "should add new line item if product does not currently existing in order" do
      @variant2 = mock_model(Variant, :id => "5678", :price => 9.99)
      
      @order.line_items.should_receive(:in_order).with(@variant2).and_return(nil)
      @order.line_items.size.should == 1

      @order.add_variant(@variant2)
      
      @order.line_items.size.should == 2
    end
    
    it "should increment the quantity of line_item by 1 when product already exists in order, and no specific quantity is supplied" do

      @order.line_items.should_receive(:in_order).with(@variant).and_return(@line_item)
      @line_item.should_receive(:save).and_return(true)
      
      @order.line_items[0].quantity.should == 1
      @order.add_variant(@variant)
    
      @order.line_items[0].quantity.should == 2
    end
    
    it "should increment the quantity of line_item by x when product already exists in order, and a specific quantity is supplied"do

      @order.line_items.should_receive(:in_order).with(@variant).and_return(@line_item)
      @line_item.should_receive(:save).and_return(true)
      
      @order.line_items[0].quantity.should == 1
      @order.add_variant(@variant, 5)
    
      @order.line_items[0].quantity.should == 6
    end
    
    it "should populate additional fields on line_item when additional_fields is present" do
        Variant.stub!(:additional_fields).and_return([
          {:name => 'Weight', :only => [:product]},
          {:name => 'Height', :only => [:product, :variant], :format => "%.2f"},
          {:name => 'Width', :only => [:variant], :format => "%.2f", :populate => [:line_item]},
          {:name => 'Depth', :only => [:variant], :populate => [:line_item]}
        ])
        
        #build / mock second line item to be returned, when we add the new variant
        @line_item2 =  LineItem.new(:variant => @variant, :quantity => 1)
        @line_item2.should_receive(:save).exactly(3).times.and_return(true)
        @line_item2.stub!(:width=) 
        @line_item2.stub!(:depth=)
        
        #mock new variant to add to order
        @variant2 = mock_model(Variant, :id => "5678", :price => 9.99, :width => 19, :depth => 79)
        
        #this is what we expect to happen
        @order.line_items.should_receive(:in_order).with(@variant2).and_return(@line_item2)
        @line_item2.should_receive(:width=).with(@variant2.width) 
        @line_item2.should_receive(:depth=).with(@variant2.depth)
          
        @order.add_variant(@variant2)
        
 
    end
  end

  describe "resume" do
    %w{in_progress shipment shipping_method creditcard charged }.each do |state|
      it "should not be available in #{state} state" do 
        @order.state = state
        @order.send("can_resume?").should == false
      end
    end
    it "should be available in canceled state" do 
      @order.state = 'canceled'
      @order.state_events = [StateEvent.new(:name => 'cancel', :previous_state => 'charged')]
      @order.send("can_resume?").should == true
    end
    it "should restore the order to the previous state" do
      @order.state_events = [StateEvent.new(:name => 'cancel', :previous_state => 'charged')]
      @order.state = 'canceled'
      @order.resume!
      @order.state.should == 'charged'
    end
    it "should not be available for legacy orders wtih no prior state information" do 
      @order.state = 'canceled'
      @order.state_events = [StateEvent.new(:name => 'cancel')]
      @order.send("can_resume?").should == false
    end
  end  
  
  describe "grant_access?" do
    it "should grant if current_user is the same as the order's user" do
      current_user = User.new
      user_session = mock_model(UserSession, :user => current_user)
      UserSession.stub!(:find).and_return(user_session)
      @order.user = current_user
      @order.grant_access?.should be_true
    end
    it "should deny if current_user is not the same as the order's user and no token" do
      current_user = User.new
      user_session = mock_model(UserSession, :user => current_user)
      UserSession.stub!(:find).and_return(user_session)
      @order.user = User.new
      @order.grant_access?.should be_false
    end
    it "should deny if current_user is not the same as the order's user and wrong token" do
      current_user = User.new
      user_session = mock_model(UserSession, :user => current_user)
      UserSession.stub!(:find).and_return(user_session)
      @order.user = User.new
      @order.token = "FOO_TOKEN"
      @order.grant_access?("WRONG_TOKEN").should be_false
    end
    it "should allow if current_user does not match order but correct token is provided" do
      token = "FOO_TOKEN"
      current_user = User.new
      user_session = mock_model(UserSession, :user => current_user)
      UserSession.stub!(:find).and_return(user_session)
      @order.user = User.new
      @order.token = token
      @order.grant_access?(token).should be_true
    end
    
  end

end