
class Array
  alias :orig_to_sentence :to_sentence
  def to_sentence(options = {})
    #Blend default options with sent through options
    options.reverse_merge!({ :connector => :array_connector.l, :skip_last_comma => Boolean(:array_skip_last_comma.l) })
    orig_to_sentence(options)
  end
end


class Time
  # Acts the same as #strftime, but returns a localized version of the
  # formatted date/time string.
  def localize(format='default')
    # unabashedly stolen from Globalize which unabashedly stole this snippet from Tadayoshi Funaba's Date class
    o = ''
    format = :date_helper_time_formats.l[format.to_s.downcase] if :date_helper_time_formats.l[format.to_s.downcase]
    format.scan(/%[EO]?.|./o) do |c|
      cc = c.sub(/^%[EO]?(.)$/o, '%\\1')
      case cc
      when '%A'; o << :date_helper_day_names.l[wday]
      when '%a'; o << :date_helper_abbr_day_names.l[wday] 
      when '%B'; o << :date_helper_month_names.l[mon]
      when '%b'; o << :date_helper_abbr_month_names.l[mon]
        #when '%c'; o << :date_helper_time_formats.l[:default] ? :date_helper_date_formats.l[:default] : strftime('%Y-%m-%d')
      when '%p'; o << if hour < 12 then :date_helper_am.l else :date_helper_pm.l end
      else;      o << c
      end
    end
    strftime(o)
  end
  alias :l :localize
end

class Date
  # Acts the same as #strftime, but returns a localized version of the formatted date string.
  def localize(format='default')
    # unabashedly stolen from Globalize which unabashedly stole this snippet from Tadayoshi Funaba's Date class
    o = ''
    format = :date_helper_date_formats.l[format.to_s.downcase] if :date_helper_date_formats.l[format.to_s.downcase]
    format.scan(/%[EO]?.|./o) do |c|
      cc = c.sub(/^%[EO]?(.)$/o, '%\\1')
      case cc
      when '%A'; o << :date_helper_day_names.l[wday]
      when '%a'; o << :date_helper_abbr_day_names.l[wday] 
      when '%B'; o << :date_helper_month_names.l[mon]
      when '%b'; o << :date_helper_abbr_month_names.l[mon]
        #when '%c'; o << :date_helper_time_formats.l[:default] ? :date_helper_date_formats.l[:default] : strftime('%Y-%m-%d')
      when '%p'; o << if hour < 12 then :date_helper_am.l else :date_helper_pm.l end
      else;      o << c
      end
    end
    strftime(o)
  end
  alias :l :localize
  
end