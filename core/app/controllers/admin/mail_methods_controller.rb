class Admin::MailMethodsController < Admin::BaseController

  before_filter :load_mail_method, :only => [:edit, :update, :destroy]
  after_filter :initialize_mail_settings

  def index
    @mail_methods = MailMethod.all
    respond_to do |format|
      format.html
    end
  end

  def new
    @mail_method = MailMethod.new
    respond_to do |format|
      format.html
    end
  end

  def create
    MailMethod.create(params[:mail_method])
    flash.notice = "Successfully created!"
    respond_to do |format|
      format.html { redirect_to admin_mail_methods_path }
    end
  end

  def edit
    respond_to do |format|
      format.html
    end
  end

  def update
    @mail_method.update_attributes(params[:mail_method])
    flash.notice = "Successfully updated!"
    respond_to do |format|
      format.html { redirect_to admin_mail_methods_path }
    end
  end

  def destroy #FIXME write test for this case
    @mail_method.destroy
    respond_to do |format|
      format.js { redirect_to admin_mail_methods_path }
    end
  end


  private

  def load_mail_method
    @mail_method = MailMethod.find(params[:id])
  end

  def initialize_mail_settings
    Spree::MailSettings.init
  end

end
