module Spree
  module PageSections
    class Video < Spree::PageSection
      alias video asset

      include Spree::MemoizedData
      MEMOIZED_METHODS = %w(video_embed)

      after_create :create_video_embed, if: -> { preferred_youtube_video_url.present? }
      after_update :update_video_embed, if: -> { video_url_changed? || video_embed.nil? }
      after_destroy :destroy_video_embed

      preference :youtube_video_url, :string
      preference :youtube_video_embed_id, :string
      preference :width_desktop, :integer, default: 70
      preference :separated, :string, default: 'horizontally'

      def default_blocks
        @default_blocks.presence || [
          Spree::PageBlocks::Heading.new(
            text: Spree.t('page_sections.video.heading_1_default'),
            preferred_text_alignment: nil,
            preferred_container_alignment: nil,
            preferred_bottom_padding: 8,
            preferred_top_padding: 24,
            preferred_size: 'small'
          ),
          Spree::PageBlocks::Heading.new(
            text: Spree.t('page_sections.video.heading_2_default'),
            preferred_text_alignment: nil,
            preferred_container_alignment: nil,
            preferred_bottom_padding: 8,
            preferred_top_padding: 24,
            preferred_size: 'large'
          ),
          Spree::PageBlocks::Heading.new(
            text: store.name,
            preferred_text_alignment: nil,
            preferred_container_alignment: nil,
            preferred_bottom_padding: 8,
            preferred_top_padding: 24,
            preferred_size: 'small'
          )
        ]
      end

      def available_blocks_to_add
        [Spree::PageBlocks::Heading]
      end

      def icon_name
        'movie'
      end

      def blocks_available?
        true
      end

      def can_sort_blocks?
        true
      end

      def video_embed
        @video_embed ||= ::ActionText::VideoEmbed.find_by(id: preferred_youtube_video_embed_id) if preferred_youtube_video_embed_id.present?
      end

      private

      def video_url_changed?
        saved_change_to_preferences? &&
          saved_change_to_preferences[0][:youtube_video_url] != saved_change_to_preferences[1][:youtube_video_url]
      end

      def create_video_embed
        oembed_response = oembed_cached_response(preferred_youtube_video_url)

        if oembed_response.present?
          embed = ::ActionText::VideoEmbed.new
          embed.url = preferred_youtube_video_url
          embed.raw_html = oembed_response.html
          embed.thumbnail_url = oembed_response.thumbnail_url

          embed.save
          update(preferred_youtube_video_embed_id: embed.id) if embed.persisted?
        end
      end

      def update_video_embed
        destroy_video_embed
        create_video_embed
      end

      def destroy_video_embed
        video_embed.destroy if video_embed.present?
      end

      def oembed_cached_response(url)
        return nil if url.blank?

        raw_response = Rails.cache.fetch(['oembed', url]) { ::OEmbed::Providers.get(url).fields.to_json }
        OEmbed::Response.create_for(raw_response, OEmbed::Providers::Youtube, url, 'json')
      rescue OEmbed::Error
        nil
      end
    end
  end
end
