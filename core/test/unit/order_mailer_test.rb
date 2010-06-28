require File.expand_path(File.dirname(__FILE__) + '/../test_helper')
class OrderMailerTest < ActionMailer::TestCase
  tests OrderMailer
  
  context "order mailer" do
    setup do
      @order = Factory.create(:order)
    end

    context "confirm email" do    
      setup do
        OrderMailer.confirm(@order).deliver
      end
      
      should "can be successfully sent" do
        assert have_sent_email
      end
      
    end

    context "cancel email" do    
      setup do
        OrderMailer.cancel(@order).deliver
      end
      
      should "can be successfully sent" do
        assert have_sent_email
      end
    end
    
    context "order_bcc and mail_bcc configurations" do
      setup do
        Spree::Config.set(:order_bcc => "tom@gmail.com, dick@gmail.com, harry@gmail.com") 
        Spree::Config.set(:mail_bcc => "tom@gmail.com, dick@gmail.com, alice@gmail.com")
        OrderMailer.deliver_confirm!(@order)
      end
      
      should "only send bcc mail to unique users" do
        assert_equal 4, ActionMailer::Base.deliveries.first.bcc.size
        assert_contains ActionMailer::Base.deliveries.first.bcc, "tom@gmail.com"
        assert_contains ActionMailer::Base.deliveries.first.bcc, "alice@gmail.com"
        assert_contains ActionMailer::Base.deliveries.first.bcc, "dick@gmail.com"
        assert_contains ActionMailer::Base.deliveries.first.bcc, "harry@gmail.com"
      end
    
    end
  end
end
