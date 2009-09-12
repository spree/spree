require File.dirname(__FILE__) + '/../../../../test/test_helper' 
require 'test_mail_queue_mailer' 
Spree::Config.set(:use_mail_queue => true)

class MailQueueTest < Test::Unit::TestCase
  
  def test_should_queue_and_then_send
    
    queue_count = QueuedMail.count
    
    TestMailQueueMailer.template_root = "lib"
    TestMailQueueMailer.deliver_notify()
    
    assert QueuedMail.count > queue_count 
    
    MailQueue.process
    
    assert QueuedMail.count == 0
  end
  
  def test_should_send_without_queue
    
    TestMailQueueMailer.template_root = "lib"
    TestMailQueueMailer.deliver_notify!()
    
    assert QueuedMail.count == 0
  end
end
 
