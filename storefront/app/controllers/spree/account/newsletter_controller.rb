module Spree
  module Account
    class NewsletterController < BaseController
      # GET /account/newsletter
      def edit; end

      # PUT /account/newsletter
      def update
        try_spree_current_user.update(newsletter_params)

        event_properties = {
          user: try_spree_current_user,
          email: try_spree_current_user.email
        }

        if try_spree_current_user.accepts_email_marketing?
          Spree::NewsletterSubscriber.subscribe(email: try_spree_current_user.email, user: try_spree_current_user)
          track_event('subscribed_to_newsletter', event_properties)
        else
          Spree::NewsletterSubscriber.find_by(email: try_spree_current_user.email)&.destroy
          track_event('unsubscribed_from_newsletter', event_properties)
        end
      end

      private

      def newsletter_params
        params.require(:user).permit(:accepts_email_marketing)
      end

      def accurate_title
        Spree.t('storefront.account.newsletter_settings')
      end
    end
  end
end
