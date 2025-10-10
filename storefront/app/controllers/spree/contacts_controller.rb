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
      Rails.error.report(
        exception || StandardError.new('Contact Form Message not sent'),
        context: { contact_id: @contact&.id },
        source: 'spree.storefront'
      )

      flash[:error] = Spree.t('storefront.contacts.message_not_sent')
    end

    def ensure_customer_support_email
      return if current_store.customer_support_email.present?

      flash[:error] = Spree.t('storefront.contacts.customer_support_email_not_configured')
      redirect_back(fallback_location: root_path)
    end
  end
end
