module Spree
  class NewsletterSubscribersController < StoreController
    skip_before_action :redirect_to_password
    before_action :load_newsletter_section, only: :create

    # POST /newsletter_subscribers
    def create
      user = Spree.user_class.find_or_initialize_by(email: newsletter_params[:email])

      if user.new_record? && user.respond_to?(:password) && user.respond_to?(:password_confirmation)
        user.password ||= SecureRandom.hex(16) # we need to set a password to pass validation
        user.password_confirmation ||= user.password
      end

      user.accepts_email_marketing = true if user.new_record? || try_spree_current_user == user

      if user.save
        track_event('subscribed_to_newsletter', { email: user.email, user: user })

        flash[:success] = Spree.t('storefront.newsletter_subscribers.success')
      else
        flash[:error] = user.errors.full_messages.to_sentence.presence || Spree.t('something_went_wrong')
      end

      respond_to do |format|
        format.html { redirect_to spree.root_path }
        format.turbo_stream
      end
    end

    private

    def newsletter_params
      params.require(:newsletter).permit(:email)
    end

    def load_newsletter_section
      return if params[:section_id].blank?

      @newsletter_section = Spree::PageSections::Newsletter.find_by(id: params[:section_id])
    end
  end
end
