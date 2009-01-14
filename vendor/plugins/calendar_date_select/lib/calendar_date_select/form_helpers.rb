# Various helpers available for use in your view
module CalendarDateSelect::FormHelpers
  
  # Similar to text_field_tag, but adds a calendar picker, naturally.
  #
  # == Arguments
  #
  #   +name+ - the html name of the tag
  #   +value+ - When specified as a string, uses value verbatim.  When Date, DateTime, Time, it converts it to a string basd off the format set by CalendarDateSelect#format=
  #   +options+ - ...
  #
  # == Options
  # 
  # === :embedded
  # 
  # Put the calendar straight into the form, rather than using a popup type of form.
  # 
  #   <%= calendar_date_select_tag "name", "2007-01-01", :embedded => true %>
  # 
  # === :hidden
  # 
  # Use a hidden element instead of a text box for a pop up calendar.  Not compatible with :embedded => true.  You'll probably want to use an onchange callback to do something with the value.
  # 
  #   <span id='cds_value' /> 
  #   <%= calendar_date_select_tag "hidden_date_selector", "", :hidden => "true", :onchange => "$('cds_value').update($F(this));" %>
  # 
  # === :image
  # 
  # Specify an alternative icon to use for the date picker.
  # 
  # To use /images/groovy.png:
  # 
  #   <%= calendar_date_select_tag "altered_image", "", :image => "groovy.png" %>
  # 
  # === :minute_interval
  # 
  # Specifies the minute interval used in the hour/minute selector.  Default is 5.
  # 
  #   <%= calendar_date_select_tag "month_year_selector_label", "", :minute_interval => 15 %>
  # 
  # === :month_year
  # 
  # Customize the month and year selectors at the top of the control.
  # 
  # Valid values:
  #  * "dropdowns" (default) - Use a separate dropdown control for both the month and year
  #  * "label" - Use static text to show the month and the year.
  # 
  #    <%= calendar_date_select_tag "month_year_selector_label", "", :month_year => "label" %>
  # 
  # === :popup => 'force'
  # 
  # Forces the user to use the popup calendar by making it's text-box read-only and causing calendar_date_select to override it's default behavior of not allowing selection of a date on a target element that is read-only.
  # 
  #   <%= calendar_date_select_tag "name", "2007-01-01", :popup => "force" %>
  # 
  # === :time
  # 
  # Show time in the controls.  There's three options:
  # 
  #  * +true+ - show an hour/minute selector.
  #  * +false+ - don't show an hour/minute selector.
  #  * +"mixed"+ - Show an hour/minute selector, but include a "all day" option - allowing them to choose whether or not to specify a time.
  # 
  # === :year_range
  # 
  # Limit the year range.  You can pass in an array or range of ruby Date/Time objects or FixNum's.
  # 
  #   <%= calendar_date_select_tag "e_date", nil, :year_range => 10.years.ago..0.years.from_now %>
  #   <%= calendar_date_select_tag "e_date", nil, :year_range => [0.years.ago, 10.years.from_now] %>
  #   <%= calendar_date_select_tag "e_date", nil, :year_range => 2000..2007 %>
  #   <%= calendar_date_select_tag "e_date", nil, :year_range => [2000, 2007] %>
  # 
  # == CALLBACKS
  # 
  # The following callbacks are available:
  # 
  #  * before_show / after_show
  #  * before_close / after_close
  #  * after_navigate - Called when navigating to a different month. Passes first parameter as a date object refering to the current month viewed
  #  * onchange - Called when the form input value changes 
  # 
  #   <%= calendar_date_select_tag "event_demo", "", 
  #     :before_show => "log('Calendar Showing');" ,
  #     :after_show => "log('Calendar Shown');" ,
  #     :before_close => "log('Calendar closing');" ,
  #     :after_close => "log('Calendar closed');",
  #     :after_navigate => "log('Current month is ' + (param.getMonth()+1) + '/' + (param.getFullYear()));",
  #     :onchange => "log('value changed to - ' + $F(this));"
  # 
  # }}}
  # 
  # All callbacks are executed within the context of the target input element.  If you'd like to access the CalendarDateSelect object itself, you can access it via "this.calendar_date_select".
  # 
  # For example:
  # 
  #   <%= calendar_date_select_tag "event_demo", "", :after_navigate => "alert('The current selected month is ' + this.calendar_date_select.selected_date.getMonth());" ,
  def calendar_date_select_tag( name, value = nil, options = {})
    options, javascript_options = calendar_date_select_process_options(options)
    value = CalendarDateSelect.format_time(value, javascript_options)

    javascript_options.delete(:format)

    options[:id] ||= name
    tag = javascript_options[:hidden] || javascript_options[:embedded] ?
      hidden_field_tag(name, value, options) :
      text_field_tag(name, value, options)

    calendar_date_select_output(tag, options, javascript_options)
  end

  # Similar to the difference between +text_field_tag+ and +text_field+, this method behaves like +text_field+
  #
  # It receives the same options as +calendar_date_select_tag+.  Need for time selection is automatically detected by checking the corresponding column meta information of Model#columns_hash
  def calendar_date_select(object, method, options={})
    obj = options[:object] || instance_variable_get("@#{object}")

    if !options.include?(:time) && obj.class.respond_to?("columns_hash")
      column_type = (obj.class.columns_hash[method.to_s].type rescue nil)
      options[:time] = true if column_type == :datetime
    end

    use_time = options[:time]

    if options[:time].to_s=="mixed"
      use_time = false if Date===(obj.respond_to?(method) && obj.send(method))
    end

    options, javascript_options = calendar_date_select_process_options(options)

    options[:value] ||=
      if(obj.respond_to?(method) && obj.send(method).respond_to?(:strftime))
        obj.send(method).strftime(CalendarDateSelect.date_format_string(use_time))
      elsif obj.respond_to?("#{method}_before_type_cast")
        obj.send("#{method}_before_type_cast")
      elsif obj.respond_to?(method)
        obj.send(method).to_s
      else
        nil
      end

    tag = ActionView::Helpers::InstanceTag.new_with_backwards_compatibility(object, method, self, options.delete(:object))
    calendar_date_select_output(
      tag.to_input_field_tag( (javascript_options[:hidden] || javascript_options[:embedded]) ? "hidden" : "text", options),
      options,
      javascript_options
    )
  end

  private
    # extracts any options passed into calendar date select, appropriating them to either the Javascript call or the html tag.
    def calendar_date_select_process_options(options)
      options, javascript_options = CalendarDateSelect.default_options.merge(options), {}
      callbacks = [:before_show, :before_close, :after_show, :after_close, :after_navigate]
      for key in [:time, :valid_date_check, :embedded, :buttons, :clear_button, :format, :year_range, :month_year, :popup, :hidden, :minute_interval] + callbacks
        javascript_options[key] = options.delete(key) if options.has_key?(key)
      end

      # if passing in mixed, pad it with single quotes
      javascript_options[:time] = "'mixed'" if javascript_options[:time].to_s=="mixed"
      javascript_options[:month_year] = "'#{javascript_options[:month_year]}'" if javascript_options[:month_year]

      # if we are forcing the popup, automatically set the readonly property on the input control.
      if javascript_options[:popup].to_s == "force"
        javascript_options[:popup] = "'force'"
        options[:readonly] = true
      end

      if (vdc=javascript_options.delete(:valid_date_check))
        if vdc.include?(";") || vdc.include?("function")
          raise ArgumentError, ":valid_date_check function is missing a 'return' statement.  Try something like: :valid_date_check => 'if (date > new(Date)) return true; else return false;'" unless vdc.include?("return");
        end

        vdc = "return(#{vdc})" unless vdc.include?("return")
        vdc = "function(date) { #{vdc} }" unless vdc.include?("function")
        javascript_options[:valid_date_check] = vdc
      end

      javascript_options[:popup_by] ||= "this" if javascript_options[:hidden]

      # surround any callbacks with a function, if not already done so
      for key in callbacks
        javascript_options[key] = "function(param) { #{javascript_options[key]} }" unless javascript_options[key].include?("function") if javascript_options[key]
      end

      javascript_options[:year_range] = format_year_range(javascript_options[:year_range] || 10)
      [options, javascript_options]
    end

    def calendar_date_select_output(input, options = {}, javascript_options = {})
      out = input
      if javascript_options[:embedded]
        uniq_id = "cds_placeholder_#{(rand*100000).to_i}"
        # we need to be able to locate the target input element, so lets stick an invisible span tag here we can easily locate
        out << content_tag(:span, nil, :style => "display: none; position: absolute;", :id => uniq_id)
        out << javascript_tag("new CalendarDateSelect( $('#{uniq_id}').previous(), #{options_for_javascript(javascript_options)} ); ")
      else
        out << " "
        out << image_tag(options[:image],
            :onclick => "new CalendarDateSelect( $(this).previous(), #{options_for_javascript(javascript_options)} );",
            :style => 'border:0px; cursor:pointer;',
			:class=>'calendar_date_select_popup_icon')
      end
      out
    end

    def format_year_range(year) # nodoc
      return year unless year.respond_to?(:first)
      return "[#{year.first}, #{year.last}]" unless year.first.respond_to?(:strftime)
      return "[#{year.first.year}, #{year.last.year}]"
    end
end

# Helper method for form builders
module ActionView
  module Helpers
    class FormBuilder
      def calendar_date_select(method, options = {})
        @template.calendar_date_select(@object_name, method, options.merge(:object => @object))
      end
    end
  end
end
