module Spree
  class ContactsController < StoreController
    before_action :load_store
    before_action :ensure_customer_support_email

    def new
      @contact = Spree::Contact.new
    end

    def create
      @contact = Spree::Contact.new(params[:contact])
      @contact.customer_support_email = current_store.customer_support_email
      @contact.request = request

      if @contact.deliver
        flash[:success] = Spree.t('storefront.contacts.message_sent')
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

      flash[:error] = Spree.t('storefront.contacts.message_not_sent')
    end

    def ensure_customer_support_email
      return if current_store.customer_support_email.present?

      flash[:error] = Spree.t('storefront.contacts.customer_support_email_not_configured')
      redirect_back_or_default root_path
    end
  end
end
