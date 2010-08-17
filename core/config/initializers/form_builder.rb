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

  def error_message_on(method, options = {})
    @template.error_message_on(@object_name, method, objectify_options(options))
  end
  
  def spree_date_picker(method, options = {}, html_options = {})
    @template.spree_date_picker(@object_name, method, options, html_options)
  end
end

ActionView::Base.field_error_proc = Proc.new{ |html_tag, instance| "<span class=\"field_with_errors\">#{html_tag}</span>".html_safe }

