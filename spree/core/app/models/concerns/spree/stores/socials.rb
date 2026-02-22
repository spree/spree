module Spree
  module Stores
    module Socials
      extend ActiveSupport::Concern

      SUPPORTED_SOCIAL_NETWORKS = %w[instagram facebook twitter pinterest tiktok youtube spotify discord].freeze

      SOCIAL_NETWORKS_CONFIG = {
        twitter: {
          input_placeholder: 'https://twitter.com/your_handle',
          profile_link: 'https://twitter.com/your_handle'
        },
        instagram: {
          input_placeholder: 'https://www.instagram.com/your_handle',
          profile_link: 'https://www.instagram.com/your_handle'
        },
        facebook: {
          input_placeholder: 'https://www.facebook.com/your_page',
          profile_link: 'https://www.facebook.com/your_page'
        },
        youtube: {
          input_placeholder: 'https://www.youtube.com/@your_channel',
          profile_link: 'https://www.youtube.com/@your_channel'
        },
        pinterest: {
          input_placeholder: 'https://pinterest.com/your_handle',
          profile_link: 'https://pinterest.com/your_handle'
        },
        tiktok: {
          input_placeholder: 'your_handle',
          profile_link: 'https://www.tiktok.com/@your_handle'
        },
        spotify: {
          input_placeholder: 'https://open.spotify.com/user/your_handle',
          profile_link: 'https://open.spotify.com/user/your_handle'
        },
        discord: {
          input_placeholder: 'https://discord.com/invite/your_handle',
          profile_link: 'https://discord.com/invite/your_handle'
        }
      }.freeze

      included do
        # generate methods for social links
        SUPPORTED_SOCIAL_NETWORKS.each do |social|
          # store the social handle in the public metadata
          store_accessor :public_metadata, social

          define_method "#{social}_link" do
            return if send(social).blank?

            send(social).match(/http/) ? send(social) : SOCIAL_NETWORKS_CONFIG[social.to_sym][:profile_link].gsub(/your_handle|your_page|your_channel/, send(social).sub(/^\//, '').sub(/^@/, ''))
          end

          define_method "#{social}_handle" do
            return if send(social).blank?

            (send(social).match(/http/) ? send(social).split('/').last : send(social)).sub(/^\//, '').gsub('@', '').split('?').first
          end
        end
      end

      def social_handle
        @social_handle ||= instagram_handle || youtube_handle || tiktok_handle
      end

      def social_links
        @social_links ||= [instagram_link, facebook_link, twitter_link, pinterest_link, youtube_link, tiktok_link, spotify_link, discord_link].compact_blank
      end
    end
  end
end
