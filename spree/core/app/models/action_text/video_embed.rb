module ActionText
  class VideoEmbed < ApplicationRecord
    include ActionText::Attachable

    validates :url, :raw_html, :thumbnail_url, presence: true

    # `to_partial_path` for the storefront render is by default "action_text/video_embeds/video_embed"

    def to_trix_content_attachment_partial_path
      'action_text/video_embeds/thumbnail'
    end
  end
end
