# Loose the div around fields with errors
ActionView::Base.field_error_proc = lambda {|tag, _| tag}



# So we get error messages wrapped in a span instead of a div which will tend to mess up forms
module ActionView::Helpers::ActiveRecordHelper

  def error_message_on(object, method, *args)
    options = args.extract_options!
    unless args.empty?
      ActiveSupport::Deprecation.warn('error_message_on takes an option hash instead of separate ' +
        'prepend_text, append_text, and css_class arguments', caller)

      options[:prepend_text] = args[0] || ''
      options[:append_text] = args[1] || ''
      options[:css_class] = args[2] || 'formError'
    end
    options.reverse_merge!(:prepend_text => '', :append_text => '', :css_class => 'formError')

    if (obj = (object.respond_to?(:errors) ? object : instance_variable_get("@#{object}"))) &&
      (errors = obj.errors.on(method))
      content_tag("span",
        "#{options[:prepend_text]}#{errors.is_a?(Array) ? errors.first : errors}#{options[:append_text]}",
        :class => options[:css_class]
      )
    else
      ''
    end
  end

end