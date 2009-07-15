module Paperclip
  module Shoulda
    module Matchers
      def validate_attachment_presence name
        ValidateAttachmentPresenceMatcher.new(name)
      end

      class ValidateAttachmentPresenceMatcher
        def initialize attachment_name
          @attachment_name = attachment_name
        end

        def matches? subject
          @subject = subject
          error_when_not_valid? && no_error_when_valid?
        end

        def failure_message
          "Attachment #{@attachment_name} should be required"
        end

        def negative_failure_message
          "Attachment #{@attachment_name} should not be required"
        end

        def description
          "require presence of attachment #{@attachment_name}"
        end

        protected

        def error_when_not_valid?
          @attachment = @subject.new.send(@attachment_name)
          @attachment.assign(nil)
          not @attachment.errors[:presence].nil?
        end

        def no_error_when_valid?
          @file = StringIO.new(".")
          @attachment = @subject.new.send(@attachment_name)
          @attachment.assign(@file)
          @attachment.errors[:presence].nil?
        end
      end
    end
  end
end

