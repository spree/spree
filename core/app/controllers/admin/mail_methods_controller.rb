class Admin::MailMethodsController < Admin::ResourceController
  after_filter :initialize_mail_settings

  private
  def initialize_mail_settings
    Spree::MailSettings.init
  end
end
