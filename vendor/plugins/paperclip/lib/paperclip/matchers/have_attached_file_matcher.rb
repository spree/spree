module Paperclip
  module Shoulda
    module Matchers
      def have_attached_file name
        HaveAttachedFileMatcher.new(name)
      end

      class HaveAttachedFileMatcher
        def initialize attachment_name
          @attachment_name = attachment_name
        end

        def matches? subject
          @subject = subject
          responds? && has_column? && included?
        end

        def failure_message
          "Should have an attachment named #{@attachment_name}"
        end

        def negative_failure_message
          "Should not have an attachment named #{@attachment_name}"
        end

        def description
          "have an attachment named #{@attachment_name}"
        end

        protected

        def responds?
          methods = @subject.instance_methods
          methods.include?("#{@attachment_name}") &&
            methods.include?("#{@attachment_name}=") &&
            methods.include?("#{@attachment_name}?")
        end

        def has_column?
          @subject.column_names.include?("#{@attachment_name}_file_name")
        end

        def included?
          @subject.ancestors.include?(Paperclip::InstanceMethods)
        end
      end
    end
  end
end
