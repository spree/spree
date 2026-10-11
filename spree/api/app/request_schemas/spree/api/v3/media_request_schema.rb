module Spree
  module Api
    module V3
      # What a media row itself carries, whichever endpoint writes it. Not
      # published on its own: each endpoint adds how the file arrives.
      class MediaRequestSchema < Spree::Api::V3::RequestSchema
        string :alt, nullable: true, example: 'Front view'
        integer :position, example: 1
        string :media_type, enum: Spree::Media::MEDIA_TYPES, example: 'image',
                            description: 'Defaults to `image`. `video` needs a `signed_id`; `external_video` needs an `external_video_url`.'
        string :external_video_url, nullable: true, description: 'YouTube or Vimeo link. Required when `media_type` is `external_video`.'
        string :poster_signed_id, description: "A `signed_id` from `files.upload()` for a video's poster frame."
        number :focal_point_x, :focal_point_y, nullable: true, description: 'Where the image is anchored when cropped, from 0 to 1.'
      end
    end
  end
end
