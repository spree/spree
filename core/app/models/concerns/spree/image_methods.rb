module Spree
  module ImageMethods
    extend ActiveSupport::Concern

    def generate_url(size:, gravity: 'center', quality: 80, background: 'show')
      return if size.blank?
      size = size.gsub(/\s+/, '')

      return unless size.match(/(\d+)x(\d+)/)

      polymorphic_path(attachment.variant(
        gravity: gravity,
        resize: size,
        extent: size,
        background: background,
        quality: quality.to_i
      ), only_path: true)
    end

    def original_url
      polymorphic_path(attachment, only_path: true)
    end
  end
end
