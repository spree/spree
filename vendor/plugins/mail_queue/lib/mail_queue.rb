# MailQueue
  
module ActionMailer
  class QueueMailer < Base
    
    class << self
    
      def method_missing(method_symbol, *parameters)#:nodoc:
        case method_symbol.id2name
          when /^deliver_([_a-z]\w*)\!/ then super(method_symbol, *parameters)
          when /^deliver_([_a-z]\w*)/ then 
            if Spree::Config[:use_mail_queue] # only use the queue if it's been enabled
              queue_mail($1, *parameters)
            else
              super(method_symbol, *parameters)
            end
          else super(method_symbol, *parameters)
        end
      end
    
      def queue_mail(method_name, *parameters)
        mail = new(method_name, *parameters).mail
        qmail = QueuedMail.new
        qmail.object = mail
        qmail.mailer = self.to_s

        qmail.save!
      end
    end
  end
end


class MailQueue < ActiveRecord::Base
   
  def MailQueue.process
    
    for qmail in QueuedMail.find(:all)
      
      mailer = qmail.mailer.constantize
      mailer.deliver(qmail.object)
      qmail.destroy
      
    end
  end

end

