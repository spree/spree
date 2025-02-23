module Spree
  class ContactsController < StoreController
    before_action :load_store
    before_action :validate_captcha, only: :create
    before_action :ensure_customer_support_email

    def new
      @contact = Spree::Contact.new
    end

    def create
      @contact = Spree::Contact.new(params[:contact])
      @contact.customer_support_email = current_store.customer_support_email
      @contact.request = request

      if @contact.deliver
        flash[:success] = 'Message sent!'
      else
        message_not_sent
      end
      redirect_to action: :new
    end

    private

    def load_store
      @store = current_store
    end

    def message_not_sent(exception = nil)
      Spree::ErrorHandler.call(
        exception: exception || StandardError.new('Contact Form Message not sent'),
        opts: {
          report_context: {
            contact: @contact&.id
          }
        }
      )

      flash[:error] = "Unfortunately we weren't able to send the email at this time. Please try again later"
    end

    def ensure_customer_support_email
      return if current_store.customer_support_email.present?

      flash[:error] = Spree.t(:customer_support_email_not_configured)
      redirect_back_or_default root_path
    end

    def validate_captcha
      return unless store_integration('recaptcha')

      hostname = request.host || @store.url_or_custom_domain
      return if verify_recaptcha(
        action: 'contacts/create',
        hostname: hostname,
        secret_key: store_integration('recaptcha').secret_key,
        site_key: store_integration('recaptcha').site_key,
        minimum_score: 0.5
      )

      flash[:error] = 'Captcha verification failed, please try again.'
      redirect_to action: :new
    end
  end
end
