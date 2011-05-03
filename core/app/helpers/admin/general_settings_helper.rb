module Admin::GeneralSettingsHelper

  def show_config_value(key,value)
    case value
      when String
        return text_field_tag("preferences[#{key}]", value, :size => 30)
      when TrueClass
        return hidden_field_tag("preferences[#{key}]",0) + check_box_tag("preferences[#{key}]", "1", value)
      when FalseClass
        return hidden_field_tag("preferences[#{key}]",0) + check_box_tag("preferences[#{key}]", "0", value)
      else
        return text_field_tag("preferences[#{key}]", value, :size => 30)
    end
  end

end
