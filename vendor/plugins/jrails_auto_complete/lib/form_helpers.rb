module FormHelpers
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
end