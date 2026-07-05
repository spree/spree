module Spree
  module Admin
    module ActionText
      class VideoEmbedsController < BaseController
        rescue_from ::OEmbed::Error, with: :video_embed_not_found

        def create
          oembed_response = oembed_cached_response(params[:url])

          video_embed = ::ActionText::VideoEmbed.new(url: params[:url])
          video_embed.raw_html = oembed_response.html
          video_embed.thumbnail_url = oembed_response.thumbnail_url

          if video_embed.save
            content = render_to_string(
              partial: 'action_text/video_embeds/thumbnail',
              locals: { video_embed: video_embed },
              formats: [:html]
            )

            render json: { sgid: video_embed.attachable_sgid, content: content }, status: :created
          else
            render json: { error: video_embed.errors.full_messages.to_sentence }, status: :unprocessable_content
          end
        end

        def destroy
          ::ActionText::VideoEmbed.from_attachable_sgid(params[:id]).destroy
        end

        private

        def video_embed_not_found
          render json: { error: I18n.t('action_text.video_embed.not_found') }, status: :not_found
        end

        def oembed_cached_response(url)
          raw_response = Rails.cache.fetch(['oembed', url]) { ::OEmbed::Providers.get(url).fields.to_json }
          OEmbed::Response.create_for(raw_response, OEmbed::Providers::Youtube, url, 'json')
        end
      end
    end
  end
end
