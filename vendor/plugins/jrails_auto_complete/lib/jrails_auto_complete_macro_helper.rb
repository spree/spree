module JrailsAutoCompleteMacroHelper
  def auto_complete_field(field_id, options = {})
    js_options = {}

    if %w(put delete).include?(options[:method])
      options[:defaultParams] = (options[:defaultParams].blank?? '' : options[:defaultParams] + '&') +
        "_method=#{options[:method].to_s}"
      options[:method] = :post
    end
    if options[:method] == :post and protect_against_forgery?
      options[:defaultParams] = (options[:defaultParams].blank?? '' : options[:defaultParams] + '&') +
        "#{h(request_forgery_protection_token.to_s)}=#{h(form_authenticity_token)}"
    end

    js_options[:url]        = "'#{url_for(options[:url])}'"
    js_options[:type]       = "'#{options[:method].to_s.upcase}'" if options[:method]
    js_options[:update]     = "'" + (options[:update] || "#{field_id}_auto_complete") + "'"
    js_options[:tokens]     = array_or_string_for_javascript(options[:tokens]) if options[:tokens]
    js_options[:callback]   = "function(element, value) { return #{options[:with]} }" if options[:with]
    js_options[:indicator]  = "'#{options[:indicator]}'" if options[:indicator]
    js_options[:select]     = "'#{options[:select]}'" if options[:select]
    js_options[:paramName]  = "'#{options[:param_name]}'" if options[:param_name]
    js_options[:frequency]  = "#{options[:frequency]}" if options[:frequency]
    js_options[:defaultParams]  = "'#{options[:defaultParams]}'" if options[:defaultParams]

    {:after_update_element => :afterUpdateElement, :on_show => :onShow, :on_hide => :onHide, :min_chars => :minChars}.each do |k, v|
      js_options[v] = options[k] if options[k]
    end

    function = "#{ActionView::Helpers::PrototypeHelper::JQUERY_VAR}('##{field_id}').autocomplete("
    function << options_for_javascript(js_options) + ')'

    javascript_tag(function)
  end

  def auto_complete_result(entries, field, phrase = nil)
    return unless entries
    items = entries.map { |entry| content_tag('li', phrase ? highlight(entry[field], phrase) : h(entry[field])) }
    content_tag('ul', items.uniq)
  end

  def auto_complete_for(object, method, options = {})
    (options[:skip_style] ? '' : auto_complete_stylesheet) +
    content_tag('div', '', :id => "#{object}_#{method}_auto_complete", :class => 'auto_complete') +
    auto_complete_field("#{object}_#{method}", { :url => { :action => "auto_complete_for_#{object}_#{method}" } }.update(options))
  end

  def text_field_with_auto_complete(object, method, tag_options = {}, completion_options = {})
    text_field(object, method, tag_options) +
    auto_complete_for(object, method, completion_options)
  end

  class InstanceTag
    def to_auto_complete(options = {})
      send(:add_default_name_and_id, options)
      @template_object.auto_complete_field(options['id'], options)
    end

    def to_text_field_with_auto_complete(options = {}, text_field_options = {})
      to_input_field_tag('text', text_field_options) + to_auto_complete(options)
    end
  end

  class FormBuilder
    def text_field_with_auto_complete(method, options = {}, auto_complete_options = {})
      text_field(method, options) + auto_complete_for(method, auto_complete_options)
    end

    def auto_complete_for(method, options = {})
      @template.auto_complete_for(@object_name, method, options)
    end
  end

  private

    def auto_complete_stylesheet
      content_tag('style', <<-EOT, :type => Mime::CSS)
        div.auto_complete {
          width: 350px;
          background: #fff;
        }
        div.auto_complete ul {
          border:1px solid #888;
          margin:0;
          padding:0;
          width:100%;
          list-style-type:none;
        }
        div.auto_complete ul li {
          margin:0;
          padding:3px;
        }
        div.auto_complete ul li.selected {
          background-color: #ffb;
        }
        div.auto_complete ul strong.highlight {
          color: #800;
          margin:0;
          padding:0;
        }
        EOT
    end
end