module Paperclip
  module Shoulda
    module Matchers
      def validate_attachment_size name
        ValidateAttachmentSizeMatcher.new(name)
      end

      class ValidateAttachmentSizeMatcher
        def initialize attachment_name
          @attachment_name = attachment_name
          @low, @high = 0, (1.0/0)
        end

        def less_than size
          @high = size
          self
        end

        def greater_than size
          @low = size
          self
        end

        def in range
          @low, @high = range.first, range.last
          self
        end

        def matches? subject
          @subject = subject
          lower_than_low? && higher_than_low? && lower_than_high? && higher_than_high?
        end

        def failure_message
          "Attachment #{@attachment_name} must be between #{@low} and #{@high} bytes"
        end

        def negative_failure_message
          "Attachment #{@attachment_name} cannot be between #{@low} and #{@high} bytes"
        end

        def description
          "validate the size of attachment #{@attachment_name}"
        end

        protected

        def override_method object, method, &replacement
          (class << object; self; end).class_eval do
            define_method(method, &replacement)
          end
        end

        def passes_validation_with_size(new_size)
          file = StringIO.new(".")
          override_method(file, :size){ new_size }
          attachment = @subject.new.attachment_for(@attachment_name)
          attachment.assign(file)
          attachment.errors[:size].nil?
        end

        def lower_than_low?
          not passes_validation_with_size(@low - 1)
        end

        def higher_than_low?
          passes_validation_with_size(@low + 1)
        end

        def lower_than_high?
          return true if @high == (1.0/0)
          passes_validation_with_size(@high - 1)
        end

        def higher_than_high?
          return true if @high == (1.0/0)
          not passes_validation_with_size(@high + 1)
        end
      end
    end
  end
end

