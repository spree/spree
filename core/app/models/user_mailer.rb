class UserMailer < ActionMailer::Base
  default_url_options[:host] = Spree::Config[:site_url]

  def password_reset_instructions(user)
    subject       Spree::Config[:site_name] + ' ' + I18n.t("password_reset_instructions")
    from          Spree::Config[:mails_from]
    recipients    user.email
    sent_on       Time.now
    body          :edit_password_reset_url => edit_password_reset_url(user.perishable_token)
  end
end
