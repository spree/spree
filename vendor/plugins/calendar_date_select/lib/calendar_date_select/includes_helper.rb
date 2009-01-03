module CalendarDateSelect::IncludesHelper
  # returns the selected calendar_date_select stylesheet (not an array)
  def calendar_date_select_stylesheets(options = {})
    options.assert_valid_keys(:style)
    "calendar_date_select/#{options[:style] || "default"}"
  end

  # returns an array of javascripts needed for the selected locale, date_format, and calendar control itself.
  def calendar_date_select_javascripts(options = {})
    options.assert_valid_keys(:format, :locale)
    files = ["calendar_date_select/calendar_date_select"]
    files << "calendar_date_select/locale/#{options[:locale]}" if options[:locale]
    files << "calendar_date_select/#{CalendarDateSelect.format[:javascript_include]}" if CalendarDateSelect.format[:javascript_include]
    files
  end

  # returns html necessary to load javascript and css to make calendar_date_select work
  def calendar_date_select_includes(*args)
    return "" if @cds_already_included
    @cds_already_included=true
    
    options = (Hash === args.last) ? args.pop : {}
    options.assert_valid_keys(:style, :format, :locale)
    options[:style] ||= args.shift
    
    javascript_include_tag(*calendar_date_select_javascripts(:locale => options[:locale], :format => options[:format])) + "\n" +
    stylesheet_link_tag(*calendar_date_select_stylesheets(:style => options[:style])) + "\n"
  end
end
