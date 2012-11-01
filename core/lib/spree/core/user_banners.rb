# Utility methods for dealing with user banners and saving
# an array of dismissed banners per user
# use symbols as banner id
module Spree
  module Core
    module UserBanners
      def self.included(base)
        base.preference :dismissed_banners, :string, :default => ''
      end

      def dismissed_banner_ids
        dismissed = self.preferred_dismissed_banners
        dismissed.split(',').map(&:to_sym)
      end

      def dismiss_banner(banner_id)
        self.preferred_dismissed_banners = dismissed_banner_ids.push(banner_id.to_sym).uniq.join(',')
      end

      def dismissed_banner?(banner_id)
        dismissed_banner_ids.include? banner_id.to_sym
      end
    end
  end
end
