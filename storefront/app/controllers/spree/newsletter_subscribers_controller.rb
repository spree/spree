module Spree
  class NewsletterSubscribersController < StoreController
    skip_before_action :redirect_to_password
    before_action :load_newsletter_section, only: :create
    rescue_from ActiveRecord::RecordNotFound, with: :subscriber_not_found

    # POST /newsletter_subscribers
    def create
      subscriber = Spree::NewsletterSubscriber.subscribe(email: newsletter_params[:email], user: try_spree_current_user)

      if subscriber.errors.any?
        flash[:error] = subscriber.errors.full_messages.to_sentence.presence || Spree.t('something_went_wrong')
      elsif subscriber.verified? && subscriber.previous_changes.blank?
        flash[:notice] = Spree.t('storefront.newsletter_subscribers.already_subscribed')
      else
        track_event('subscribed_to_newsletter', { email: subscriber.email, user: try_spree_current_user })
        flash[:success] = Spree.t('storefront.newsletter_subscribers.success')
      end

      respond_to do |format|
        format.html { redirect_to spree.root_path }
        format.turbo_stream
      end
    end

    # GET /newsletter_subscribers/verify?token=VERIFICATION_TOKEN
    def verify
      raise ActiveRecord::RecordNotFound if params[:token].blank?

      subscriber = ActiveRecord::Base.connected_to(role: :writing) do
        Spree::NewsletterSubscriber.verify(token: params[:token])
      end

      if subscriber.verified?
        redirect_to spree.root_path, notice: Spree.t('storefront.newsletter_subscribers.verified')
      else
        redirect_to spree.root_path, alert: Spree.t('storefront.newsletter_subscribers.verification_failed')
      end
    end

    private

    def subscriber_not_found
      redirect_to spree.root_path, alert: Spree.t('storefront.newsletter_subscribers.verification_failed')
    end

    def newsletter_params
      params.require(:newsletter).permit(:email)
    end

    def load_newsletter_section
      return if params[:section_id].blank?

      @newsletter_section = Spree::PageSections::Newsletter.find_by(id: params[:section_id])
    end
  end
end
