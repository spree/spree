module Spree
  # Value object that reads a YouTube or Vimeo link and tells you which
  # provider it belongs to, which video it points at, and how to embed it.
  #
  # Spree does this once, at the write boundary, so the URL is validated before
  # it is stored and every storefront reads the same derived values instead of
  # re-implementing link parsing.
  class ExternalVideo
    include ActiveModel::Model
    include ActiveModel::Attributes

    YOUTUBE_HOSTS = %w[youtube.com www.youtube.com m.youtube.com youtu.be www.youtu.be].freeze
    VIMEO_HOSTS = %w[vimeo.com www.vimeo.com player.vimeo.com].freeze

    YOUTUBE_ID_FORMAT = /\A[\w-]{11}\z/
    VIMEO_ID_FORMAT = /\A\d+\z/

    attribute :provider, :string
    attribute :video_id, :string

    # Reads a URL and returns the video it describes, or nil when the URL is
    # blank, malformed, or points somewhere Spree doesn't support.
    #
    # @param url [String, nil]
    # @return [Spree::ExternalVideo, nil]
    def self.parse(url)
      return nil if url.blank?

      uri = begin
        URI.parse(url.strip)
      rescue URI::InvalidURIError
        return nil
      end

      return nil unless uri.scheme.in?(%w[http https])

      host = uri.host&.downcase
      return nil if host.blank?

      if host.in?(YOUTUBE_HOSTS)
        youtube_from(uri, host)
      elsif host.in?(VIMEO_HOSTS)
        vimeo_from(uri)
      end
    end

    # @return [Boolean] whether the URL is one Spree can embed
    def self.supported?(url)
      parse(url).present?
    end

    def self.youtube_from(uri, host)
      video_id =
        if host.include?('youtu.be')
          uri.path.delete_prefix('/')
        elsif uri.path == '/watch'
          URI.decode_www_form(uri.query.to_s).to_h['v']
        else
          # /embed/ID, /shorts/ID, /live/ID
          uri.path.split('/').last
        end

      return nil unless video_id.to_s.match?(YOUTUBE_ID_FORMAT)

      new(provider: 'youtube', video_id: video_id)
    end
    private_class_method :youtube_from

    def self.vimeo_from(uri)
      # /ID, /video/ID, /channels/name/ID all end in the numeric id.
      video_id = uri.path.split('/').last

      return nil unless video_id.to_s.match?(VIMEO_ID_FORMAT)

      new(provider: 'vimeo', video_id: video_id)
    end
    private_class_method :vimeo_from

    # @return [String] URL for an iframe player
    def embed_url
      case provider
      when 'youtube' then "https://www.youtube.com/embed/#{video_id}"
      when 'vimeo' then "https://player.vimeo.com/video/#{video_id}"
      end
    end

    # @return [String] canonical watch URL on the provider's own site
    def watch_url
      case provider
      when 'youtube' then "https://www.youtube.com/watch?v=#{video_id}"
      when 'vimeo' then "https://vimeo.com/#{video_id}"
      end
    end

    # Provider-hosted still frame. YouTube serves one at a predictable URL;
    # Vimeo requires an API call, so it has none here and the merchant uploads
    # a poster instead.
    #
    # @return [String, nil]
    def thumbnail_url
      return "https://img.youtube.com/vi/#{video_id}/maxresdefault.jpg" if provider == 'youtube'
    end
  end
end
