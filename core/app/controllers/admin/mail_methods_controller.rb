class Admin::MailMethodsController < Admin::BaseController
  resource_controller

  after_filter :initialize_mail_settings

  update.wants.html { redirect_to collection_url }
  create.wants.html { redirect_to collection_url }

  private
  def initialize_mail_settings
    Spree::MailSettings.init
  end
end