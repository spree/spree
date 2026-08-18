FactoryBot.define do
  # `:asset` and `:image` are the pre-6.0 names, kept so existing suites and
  # extensions keep building media without a rename.
  factory :media, aliases: %i[asset image], class: Spree::Media do
    position { 1 }
    alt {}

    after(:build) do |media|
      if media.media_type == 'image' && !media.attachment.attached?
        media.attachment.attach(
          io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'thinking-cat.jpg'),
          filename: 'thinking-cat.jpg'
        )
      end
    end

    factory :video_media, aliases: [:video_asset] do
      media_type { 'video' }

      after(:build) do |media|
        unless media.attachment.attached?
          media.attachment.attach(
            io: File.new(Spree::Core::Engine.root + 'spec/fixtures' + 'tiny-video.mp4'),
            filename: 'tiny-video.mp4',
            content_type: 'video/mp4'
          )
        end
      end
    end

    factory :external_video_media, aliases: [:external_video_asset] do
      media_type { 'external_video' }
      external_video_url { 'https://www.youtube.com/watch?v=dQw4w9WgXcQ' }
    end
  end
end
