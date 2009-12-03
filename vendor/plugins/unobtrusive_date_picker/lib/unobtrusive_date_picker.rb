require File.join(File.dirname(__FILE__), '12_hour_time')

module UnobtrusiveDatePicker
  
  DATEPICKER_DEFAULT_NAME_ID_SUFFIXES = { :year  => {:id => '',   :name => 'year'},
                                          :month => {:id => 'mm', :name => 'month'},
                                          :day   => {:id => 'dd', :name => 'day'} }

  DATEPICKER_DAYS_OF_WEEK = { :Monday     => '0',
                              :Tuesday    => '1',
                              :Wednesday  => '2',
                              :Thursday   => '3',
                              :Friday     => '4',
                              :Saturday   => '5',
                              :Sunday     => '6'}
  
  DATEPICKER_DIVIDERS = { 'slash' => '/',
                          'dash'  => '-',
                          'dot'   => '.',
                          'space' => ' ' }
  
  RANGE_DATE_FORMAT = '%Y-%m-%d'

  # == Unobtrusive Date-Picker Helper
  # 
  # This Module helps to create date and date-time fields that use the 
  # Unobtrusive Date-Picker Javascript Widget.
  #
  # They also use the 12-hour AM/PM time format.
  #
  module UnobtrusiveDatePickerHelper

    ##
    # Creates the date picker with the calendar widget.
    #
    def unobtrusive_date_picker(object_name, method, options = {}, html_options = {})
      ActionView::Helpers::InstanceTag.new(object_name, method, self, options.delete(:object)).to_datepicker_date_select_tag(options, html_options)
    end

    ##
    # Creates the date-time picker with the calendar widget, and AM/PM select.
    #
    def unobtrusive_datetime_picker(object_name, method, options = {}, html_options = {})
      ActionView::Helpers::InstanceTag.new(object_name, method, self, options.delete(:object)).to_datepicker_datetime_select_tag(options, html_options)
    end
    
    ##
    # Creates the date picker with the calendar widget.
    #
    def unobtrusive_date_text_picker(object_name, method, options = {}, html_options = {})
      ActionView::Helpers::InstanceTag.new(object_name, method, self, options.delete(:object)).to_datepicker_text_tag(options, html_options)
    end
    
    def unobtrusive_datetime_picker_tags(datetime = Time.current, options = {}, html_options = {})
      datetime ||= Time.current
      DateTimePickerSelector.new(datetime, options.merge(:twelve_hour => true), html_options).select_datetime
    end

    def unobtrusive_date_picker_tags(date = Date.current, options = {}, html_options = {})
      date ||= Date.current
      DateTimePickerSelector.new(date, options, html_options).select_date
    end
    
    ##
    # Creates the text field based date picker with the calendar widget without a model object.
    #
    def unobtrusive_date_text_picker_tag(name, date = Date.current, options = {}, html_options = {})
      date ||= Date.current
      options = merge_defaults_for_text_picker(options)
      DateTimePickerSelector.new(date, options, html_options).text_date_picker(name)
    end
    
    private
      def merge_defaults_for_text_picker(options)
        defaults = {:format => 'm-d-y', :divider => 'slash'}
        options = defaults.merge(options)
      end

  end

  module AssetTagHelper
    ##
    # This will add the necessary <link> and <script> tags to include the necessary stylesheet and
    # javascripts.
    #
    def unobtrusive_datepicker_includes(options = {})
      tags = []
      tags << javascript_include_tag('datepicker', options)
      tags << javascript_include_tag("lang/#{I18n.locale.to_s[0..1]}", options)
      tags << stylesheet_link_tag('datepicker', options)
      tags * "\n"
    end
  end
  
  module OptionParser
    protected
    def parse_divider_option(option)
      if DATEPICKER_DIVIDERS.keys.include?(option)
        option
      else
        DATEPICKER_DIVIDERS.find {|name, value| option == value}.first
      end
    end

    def format_date_value_for_text_field(value, format, divider_option)
      divider = DATEPICKER_DIVIDERS[parse_divider_option(divider_option)]
      format_string = format.downcase.gsub(/(m|d)/, '%\1').gsub(/y/, '%Y').gsub('-', divider)
      value.nil? ? '' : value.strftime(format_string)
    end
    
    def get_html_classes_for_datepicker(options, html_options_class, extra_class = nil)
      html_classes = make_date_picker_class_options(options)
      html_classes << extra_class if extra_class
      html_options_class.blank? ? 
        html_classes.join(' ') : "#{html_options_class} #{html_classes.join(' ')}"
    end
    
    def make_date_picker_class_options(options)
      html_classes = []

      if options[:highlight_days]
        highlight_days = parse_days_of_week(options[:highlight_days])
        if !highlight_days.blank?
          html_classes << "highlight-days-#{highlight_days}"
        end
      end

      if options[:range_low]
        range_low = parse_range_option(options[:range_low], 'low')
        if !range_low.blank?
          html_classes << range_low
        end
      end

      if options[:range_high]
        range_high = parse_range_option(options[:range_high], 'high')
        if !range_high.blank?
          html_classes << range_high
        end
      end

      if options[:disable_days]
        disable_days = parse_days_of_week(options[:disable_days])
        if !disable_days.blank?
          html_classes << "disable-days-#{disable_days}"
        end
      end

      if options[:no_transparency]
        html_classes << 'no-transparency'
      end

      if options[:format] && %W(d-m-y m-d-y y-m-d).include?(options[:format].downcase)
        html_classes << "format-#{options[:format].downcase}"
      end

      if options[:divider]
        html_classes << "divider-#{parse_divider_option(options[:divider])}"
      end

      html_classes
    end

    def parse_days_of_week(option)
      if option.is_a? String
        option
      elsif option.is_a? Symbol
        DATEPICKER_DAYS_OF_WEEK[option]
      elsif option.is_a? Array
        days = ''
        option.each do |day|
          days << DATEPICKER_DAYS_OF_WEEK[day]
        end
        days
      end
    end

    def parse_range_option(option, direction)
      if option.is_a? Symbol
        case option
        when :today
          range_class = 'today'
        when :tomorrow
          range_class = Date.tomorrow.strftime(RANGE_DATE_FORMAT)
        when :yesterday
          range_class = Date.yesterday.strftime(RANGE_DATE_FORMAT)
        end
      elsif option.is_a? String
        if !option.blank?
          range_class = Date.parse(option).strftime(RANGE_DATE_FORMAT)
        else
          range_class = nil
        end
      elsif (option.is_a?(Date) || option.is_a?(DateTime) || option.is_a?(Time))
        range_class = option.strftime(RANGE_DATE_FORMAT)
      else
        range_class = nil
      end

      if !range_class.blank?
        range_class = 'range-' + direction + '-' + range_class
      else
        nil
      end
    end
  end
  
  class DateTimePickerSelector < ActionView::Helpers::DateTimeSelector
    include ActionView::Helpers::FormTagHelper
    include OptionParser
    
    POSITION = {
      :year => 1, :month => 2, :day => 3, :hour => 4, :minute => 5,
      :second => 6, :ampm => 7
    }
    # XXX would like to do this, but it's frozen
    # POSITION[:ampm] = 7

    # We give them negative values so can differentiate between normal
    # date/time values. The way the multi param stuff works, from what I
    # can see, results in a variable number of fields (if you tell it to
    # include seconds, for example). So we expect the AM/PM field, if
    # present, to be last and have a negative value.
    AM = -1
    PM = -2
    
    def text_date_picker(name)
      value = format_date_value_for_text_field(@datetime, @options[:format], @options[:divider])
      @html_options[:class] = get_html_classes_for_datepicker(@options, @html_options[:class])
      text_field_tag(name, value, @html_options)
    end
 
    def select_hour_with_ampm
      unless @options[:twelve_hour]
        return select_hour_without_ampm
      end

      if @options[:use_hidden] || @options[:discard_hour]
        build_hidden(:hour, hour12)
      else
        build_options_and_select(:hour, hour12, :start => 1, :end => 12)
      end
    end

    alias_method_chain :select_hour, :ampm

    def select_ampm
      selected = hour < 12 ? AM : PM

      # XXX i18n? 
      label = { AM => 'AM', PM => 'PM' }
      ampm_options = []
      [AM, PM].each do |meridiem|
        option = { :value => meridiem }
        option[:selected] = "selected" if selected == meridiem
        ampm_options << content_tag(:option, label[meridiem], option) + "\n"
      end
      build_select(:ampm, ampm_options.join)
    end
    
    private
      def build_selects_from_types_with_ampm(order)
        order += [:ampm] if @options[:twelve_hour] and !order.include?(:ampm)
        build_selects_from_types_without_ampm(order)
      end

      alias_method_chain :build_selects_from_types, :ampm

      def hour12
        h12 = hour % 12
        h12 = 12 if h12 == 0
        return h12
      end
    
      def build_select(type, select_options_as_html)
        select_options = @html_options.merge(
          :id => input_id_from_type(type, @html_options[:id]),
          :name => input_name_from_type(type)
        )
        select_options.merge!(:disabled => 'disabled') if @options[:disabled]
        
        if type.to_sym == :year
          select_options[:class] = get_html_classes_for_datepicker(@options, select_options[:class], 'split-date')
        end

        select_html = "\n"
        select_html << content_tag(:option, '', :value => '') + "\n" if @options[:include_blank]
        select_html << prompt_option_tag(type, @options[:prompt]) + "\n" if @options[:prompt]
        select_html << select_options_as_html.to_s

        content_tag(:select, select_html, select_options) + "\n"
      end
      
      def build_hidden(type, value)
        hidden_html_options = {
          :type => "hidden",
          :id => input_id_from_type(type, @html_options[:id]),
          :name => input_name_from_type(type),
          :value => value
        }
        
        if type.to_sym == :year
          hidden_html_options[:class] = get_html_classes_for_datepicker(@options, hidden_html_options[:class], 'split-date')
        end
        
        tag(:input, hidden_html_options) + "\n"
      end
      
      def input_id_from_type(type, html_options_id = nil)
        if html_options_id.blank?
          prefix = @options[:prefix] || ActionView::Helpers::DateTimeSelector::DEFAULT_PREFIX
          prefix += "_#{@options[:index]}" if @options.has_key?(:index)
          prefix += "_#{@options[:field_name]}" if @options.has_key?(:field_name)
        else
          prefix = html_options_id
        end
        case type.to_sym
          when :year
            prefix
          when :month
            prefix + '-mm'
          when :day
            prefix + '-dd'
          else
            super(type)
        end
      end
      
  end

end
# /UnobtrusiveDatePicker

module ActionView # :nodoc: all
  module Helpers
    class InstanceTag
      include UnobtrusiveDatePicker::UnobtrusiveDatePickerHelper
      include UnobtrusiveDatePicker::OptionParser

      def to_datepicker_date_select_tag(options = {}, html_options = {})
        datepicker_selector(options, html_options).select_date
      end

      def to_datepicker_datetime_select_tag(options = {}, html_options = {})
        datepicker_selector(options.merge(:twelve_hour => true), html_options).select_datetime
      end

      def to_datepicker_text_tag(options = {}, html_options = {})
        options = merge_defaults_for_text_picker(options)
        html_options[:class] = get_html_classes_for_datepicker(options, html_options[:class])
        html_options[:value] = format_date_value_for_text_field(value(object), options[:format], options[:divider])
        to_input_field_tag('text', html_options)
      end

      private
        def datepicker_selector(options, html_options)
          datetime = value(object) || default_datetime(options)
          datetime = Time.zone.local_to_utc(datetime)

          options = options.dup
          options[:field_name]           = @method_name
          options[:include_position]     = true
          options[:prefix]             ||= @object_name
          options[:index]                = @auto_index if @auto_index && !options.has_key?(:index)
          options[:datetime_separator] ||= ' &mdash; '
          options[:time_separator]     ||= ' : '

          UnobtrusiveDatePicker::DateTimePickerSelector.new(datetime, options.merge(:tag => true), html_options)
        end
    end
  end
end

module ActionView::Helpers::PrototypeHelper
  class JavaScriptGenerator
    module GeneratorMethods
      def unobtrusive_date_picker_create(id = nil)
        if id
          call "datePickerController.create", "$(#{id})"
        else
          record "datePickerController.create"
        end
      end
      
      def unobtrusive_date_picker_cleanup(id = nil)
        record "datePickerController.cleanUp"
      end
    end
  end
end


module ActionView # :nodoc: all
  module Helpers
    class FormBuilder
      def unobtrusive_date_picker(method, options = {}, html_options = {})
        @template.unobtrusive_date_picker(@object_name, method, objectify_options(options), html_options)
      end
      
      def unobtrusive_date_text_picker(method, options = {}, html_options = {})
        @template.unobtrusive_date_text_picker(@object_name, method, objectify_options(options), html_options)
      end

      def unobtrusive_datetime_picker(method, options = {}, html_options = {})
        @template.unobtrusive_datetime_picker(@object_name, method, objectify_options(options), html_options)
      end
    end
  end
end
