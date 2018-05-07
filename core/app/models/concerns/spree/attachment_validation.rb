module Spree
  module AttachmentValidation
    def check_attachment_content_type
      if attachment.attached? && !attachment.content_type.in?(accepted_image_types)
        attachment.purge
        errors.add(:attachment, :not_allowed_content_type)
      end
    end
  end
end
