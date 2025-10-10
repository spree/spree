#
# Allow some application_helper methods to be used in the scoped form_for manner
#
class ActionView::Helpers::FormBuilder
  def error_message_on(method, options = {})
    @template.error_message_on(@object_name, method, objectify_options(options))
  end
end

ActionView::Base.field_error_proc = proc { |html_tag, _instance| "<span class=\"field_with_errors\">#{html_tag}</span>".html_safe }
