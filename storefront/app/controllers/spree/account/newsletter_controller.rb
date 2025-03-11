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
          track_event('subscribed_to_newsletter', event_properties)
        else
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
