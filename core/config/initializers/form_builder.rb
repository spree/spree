#
# Allow some application_helper methods to be used in the scoped form_for manner
#
class ActionView::Helpers::FormBuilder
  def label(method, text = nil, options={})
    @template.label(@object_name,method,text,options)
  end

  def field_container(method, options = {}, &block)
    @template.field_container(@object_name,method,options,&block)
  end

  %w(error_message_on).each do |selector|
    src = <<-end_src
      def #{selector}(method, options = {})
        @template.send(#{selector.inspect}, @object_name, method, objectify_options(options))
      end
    end_src
    class_eval src, __FILE__, __LINE__
  end

end