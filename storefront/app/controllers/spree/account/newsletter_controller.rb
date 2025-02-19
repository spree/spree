module Spree
  module Account
    class NewsletterController < BaseController
      def edit; end

      def update
        @user.update(newsletter_params)
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
