# This code used to borrow heavily from Radiant CMS but it was screwing up the use of helpers in ActionMailer.  
# There didn't seem to be any real use for this file other then to make ActionMailer::Base aware of the template_root 
# (which for some reason was not working with the Radiant approach anyways.)

require 'action_mailer'

# This line seems to be necessary in order to help ActionMailer find the required views
ActionMailer::Base.template_root = "#{SPREE_ROOT}/app/views"