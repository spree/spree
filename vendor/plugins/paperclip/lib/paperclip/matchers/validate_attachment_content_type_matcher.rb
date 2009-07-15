module Paperclip
  module Shoulda
    module Matchers
      def validate_attachment_content_type name
        ValidateAttachmentContentTypeMatcher.new(name)
      end

      class ValidateAttachmentContentTypeMatcher
        def initialize attachment_name
          @attachment_name = attachment_name
        end

        def allowing *types
          @allowed_types = types.flatten
          self
        end

        def rejecting *types
          @rejected_types = types.flatten
          self
        end

        def matches? subject
          @subject = subject
          @allowed_types && @rejected_types &&
          allowed_types_allowed? && rejected_types_rejected?
        end

        def failure_message
          "Content types #{@allowed_types.join(", ")} should be accepted" +
          " and #{@rejected_types.join(", ")} rejected by #{@attachment_name}"
        end

        def negative_failure_message
          "Content types #{@allowed_types.join(", ")} should be rejected" + 
          " and #{@rejected_types.join(", ")} accepted by #{@attachment_name}"
        end

        def description
          "validate the content types allowed on attachment #{@attachment_name}"
        end

        protected

        def allow_types?(types)
          types.all? do |type|
            file = StringIO.new(".")
            file.content_type = type
            attachment = @subject.new.attachment_for(@attachment_name)
            attachment.assign(file)
            attachment.errors[:content_type].nil?
          end
        end

        def allowed_types_allowed?
          allow_types?(@allowed_types)
        end

        def rejected_types_rejected?
          not allow_types?(@rejected_types)
        end
      end
    end
  end
end

