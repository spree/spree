require 'test_helper'

class OrderStateTest < ActiveSupport::TestCase
  context "Order" do
     setup do
        @order = create_complete_order    
        @order.checkout.update_attribute("state", "complete")

        #only want one line item for ease of testing
        @order.line_items.destroy_all
        Factory(:line_item, :order => @order, :variant => Factory(:variant), :quantity => 2, :price => 100.00)
        
        #make sure totals get recalculated
        @order.reload
        @order.save
      end

      should "be in_progress initally" do
        assert @order.in_progress?
      end

      context "with a complete checkout and payment" do
        setup do 
          @order.complete!
          @order.payments.create(:amount => @order.total)  
          @order.update_totals!        
        end

        should_change("@order.state", :from => "in_progress", :to => "new") { @order.state }
        
        should "allow cancel" do
          assert @order.can_cancel?
        end
        
        should "not allow resume" do
          assert !@order.can_resume?
        end
        
        should "allow ship" do
          assert @order.can_ship?
        end

        context "when canceled" do
          setup do
            @order.cancel!
          end
        
          should_change("@order.state", :from => "new", :to => "canceled") { @order.state }
        
          should "allow resume" do
            assert @order.can_resume?
          end
        
          context "and then resumed" do
            setup do
              @order.resume!
            end
        
            should_change("@order.state", :from => "canceled", :to => "new") { @order.state }
          end
        end

        context "and all shipments are shipped" do
          setup do
            shipment = @order.shipment.reload
            shipment.ship!
            @order.reload
          end

          should_change("@order.state", :from => "paid", :to => "shipped") { @order.state }
          
          context "and a return_authorization with all inventory_units returned" do
            setup do
              ra = ReturnAuthorization.new(:order => @order, :amount => 50.00)
              ra.add_variant(@order.line_items.first.variant_id, @order.line_items.first.quantity)
              ra.save!
              @order.reload
            end
          
            should_change("@order.state", :from => "shipped", :to => "awaiting_return") { @order.state }
          
            context "and received" do
              setup do
                @order.return_authorizations.first.receive!
                @order.reload
              end
          
              should_change("@order.state", :from => "awaiting_return", :to => "credit_owed") { @order.state }
          
              context "and a negative payment is created" do
                setup do  
                  @order.payments.create(:amount => -50.00)
                  #@creditcard.credit(50.00, @creditcard.authorization)
                  @order.reload
                end
          
                should_change("@order.state", :from => "credit_owed", :to => "returned") { @order.state }
              end
          
            end
          
          end

          context "and a return_authorization with not all inventory_units are returned is created" do
            setup do
              ra = ReturnAuthorization.new(:order => @order, :amount => 50.00)
              ra.add_variant(@order.line_items.first.variant_id, (@order.line_items.first.quantity - 1))
              ra.save!
              @order.reload
            end
          
            should_change("@order.state", :from => "shipped", :to => "awaiting_return") { @order.state }
          
            context "and received" do
              setup do
                @order.return_authorizations.first.receive!
                @order.reload
              end
          
              should_change("@order.state", :from => "awaiting_return", :to => "credit_owed") { @order.state }
          
              context "and a negative payment is created" do
                setup do     
                  @order.payments.create(:amount => -50.00)
                  @order.reload
                end
              
                should_change("@order.state", :from => "credit_owed", :to => "shipped") { @order.state }
              end
          
            end
          
          end

        end

        context "and an additional credit is added" do
          setup do
            @credit = Factory(:credit, :amount => 2.00, :order => @order)
            @order.update_totals!
            @order.reload
          end
        
          should_change("@order.state", :from => "paid", :to => "credit_owed") { @order.state }
        
          context "and a negative payment is created" do
            setup do          
              @order.payments.create(:amount => -2.00)
              @order.update_totals! 
              @order.reload
            end        
            should_change("@order.state", :from => "credit_owed", :to => "paid") { @order.state }
          end
        
        end

        context "and an additional charge is added" do
          setup do
            @credit = Factory(:charge, :amount => 3.00, :order => @order)
            @order.update_totals!
            @order.reload
          end
        
          should_change("@order.state", :from => "paid", :to => "balance_due") { @order.state }
        
          context "and a payment is created" do
            setup do
              CreditcardPayment.create(:order => @order, :amount => 3.00, :creditcard => @order.checkout.creditcard)
            end
        
            should_change("@order.state", :from => "balance_due", :to => "paid") { @order.state }
          end
        
        end

      end
  end
end