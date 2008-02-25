class CalendarDateSelect
  module IncludesHelper
    def calendar_date_select_includes(*args)
      return "" if @cds_already_included
      @cds_already_included=true
      
      options = (Hash === args.last) ? args.pop : {}
      options.assert_valid_keys(:style, :format, :locale)
      
      style = options[:style] || args.shift
      locale = options[:locale]
      cds_css_file = style ? "calendar_date_select/#{style}" : "calendar_date_select/default"
      
      output = []
      output << javascript_include_tag("calendar_date_select/calendar_date_select")
      output << javascript_include_tag("calendar_date_select/locale/#{locale}") if locale
      output << javascript_include_tag(CalendarDateSelect.javascript_format_include) if CalendarDateSelect.javascript_format_include
      output << stylesheet_link_tag(cds_css_file)
      output * "\n"
    end
  end
end
