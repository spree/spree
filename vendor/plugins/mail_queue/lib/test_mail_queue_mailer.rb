

class TestMailQueueMailer < ActionMailer::QueueMailer 
  
  def notify(sent_at = Time.now) 
    @subject = 'TestMailerClass#notify' 
    @recipients = ['nate@mailinator.com'] 
    @from = 'from@mailinator.com' 
    @sent_on = sent_at 
    @headers = {} 
    @body = {} 
    
    Net::HTTP.start("www.google.com") { |http|
      resp = http.get("/intl/en_ALL/images/logo.gif")
      attachment :content_type => "image/gif",
              :body => resp.body
    }
  end 
end
