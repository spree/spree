class UserMailer < ActionMailer::Base
  default_url_options[:host] = Spree::Config[:site_url]
  default :from => Spree::Config[:mails_from]

  def password_reset_instructions(user)
    @edit_password_reset_url = edit_password_reset_url(user.perishable_token)
    mail(:to => user.email,
         :subject => Spree::Config[:site_name] + ' ' + I18n.t("password_reset_instructions"))
  end

end

