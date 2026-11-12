module Spree
  module Api
    module V3
      # What a media row itself carries, whichever endpoint writes it. Not
      # published on its own: each endpoint adds how the file arrives.
      class MediaRequestSchema < Spree::Api::V3::RequestSchema
        attribute :alt, :string, nullable: true, example: 'Front view'
        attribute :position, :integer, example: 1
        attribute :media_type, :string,
          choices: Spree::Media::MEDIA_TYPES,
          example: 'image',
          description: 'Defaults to `image`. `video` needs a `signed_id`; `external_video` needs an `external_video_url`.'
        attribute :external_video_url, :string,
          nullable: true,
          description: 'YouTube or Vimeo link. Required when `media_type` is `external_video`.'
        attribute :poster_signed_id, :string,
          description: "A `signed_id` from `files.upload()` for a video's poster frame."
        attribute :focal_point_x, :number,
          nullable: true,
          description: 'Where the image is anchored when cropped, from 0 to 1.'
        attribute :focal_point_y, :number,
          nullable: true,
          description: 'Where the image is anchored when cropped, from 0 to 1.'
      end
    end
  end
end
