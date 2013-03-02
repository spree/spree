module Spree
  module Admin
    class MailMethodsController < Spree::Admin::BaseController
      after_filter :initialize_mail_settings

      def update
        if params[:smtp_password].blank?
          params.delete(:smtp_password)
        end

        params.each do |name, value|
          next unless Spree::Config.has_preference? name
          Spree::Config[name] = value
        end

        flash[:success] = t(:successfully_updated, :resource => t(:mail_methods))
        render :edit
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
