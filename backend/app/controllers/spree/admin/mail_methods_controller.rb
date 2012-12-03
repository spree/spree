module Spree
  module Admin
    class MailMethodsController < ResourceController
      after_filter :initialize_mail_settings

      def update
        if params[:mail_method][:preferred_smtp_password].blank?
          params[:mail_method].delete(:preferred_smtp_password)
        end
        super
      end

      def testmail
        @mail_method = Spree::MailMethod.find(params[:id])
        if TestMailer.test_email(@mail_method, try_spree_current_user).deliver
          flash[:success] = t('admin.mail_methods.testmail.delivery_success')
        else
          flash[:error] = t('admin.mail_methods.testmail.delivery_error')
        end
      rescue Exception => e
        flash[:error] = t('admin.mail_methods.testmail.error') % {:e => e}
      ensure
        redirect_to :back
      end

      private
      def initialize_mail_settings
        Spree::Core::MailSettings.init
      end
    end
  end
end
