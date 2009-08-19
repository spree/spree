#
# == Rails Twelve Hour Time Plugin
# 
# http://code.google.com/p/rails-twelve-hour-time-plugin/
# 
# ==== Authors
# * Nick Muerdter (original code)
# * Maurice Aubrey
# 
# ==== Used for
# Allows UnobtrusiveDatePicker::UnobtrusiveDatePickerHelper to use a AM/PM select of it's own, 
# and still be processed correctly by Active Record.
# 

# :enddoc:
if defined? ActiveRecord
class ActiveRecord::Base # :nodoc: all
  def instantiate_time_object_with_ampm(name, values)
    if values.last < 0
      ampm = values.pop
      if ampm == ActionView::Helpers::DateTimeSelector::AM and values[3] == 12
        values[3] = 0
      elsif ampm == ActionView::Helpers::DateTimeSelector::PM and values[3] != 12
        values[3] += 12
      end
    end

    instantiate_time_object_without_ampm(name, values)
  end

  alias_method_chain :instantiate_time_object, :ampm
end
end

ActionView::Helpers::DateTimeSelector.send(:remove_const, :POSITION)
ActionView::Helpers::DateTimeSelector.const_set(:POSITION, {
  :year => 1, :month => 2, :day => 3, :hour => 4, :minute => 5,
  :second => 6, :ampm => 7
})

# Included manully in UnobtrusiveDatePicker
# module ActionView::Helpers
#   class DateTimeSelector
#     POSITION = {
#       :year => 1, :month => 2, :day => 3, :hour => 4, :minute => 5,
#       :second => 6, :ampm => 7
#     }
#     # XXX would like to do this, but it's frozen
#     # POSITION[:ampm] = 7
# 
#     # We give them negative values so can differentiate between normal
#     # date/time values. The way the multi param stuff works, from what I
#     # can see, results in a variable number of fields (if you tell it to
#     # include seconds, for example). So we expect the AM/PM field, if
#     # present, to be last and have a negative value.
#     AM = -1
#     PM = -2
#  
#     def select_hour_with_ampm
#       unless @options[:twelve_hour]
#         return select_hour_without_ampm
#       end
# 
#       if @options[:use_hidden] || @options[:discard_hour]
#         build_hidden(:hour, hour12)
#       else
#         build_options_and_select(:hour, hour12, :start => 1, :end => 12)
#       end
#     end
# 
#     alias_method_chain :select_hour, :ampm
# 
#     def select_ampm
#       selected = hour < 12 ? AM : PM
# 
#       # XXX i18n? 
#       label = { AM => 'AM', PM => 'PM' }
#       ampm_options = []
#       [AM, PM].each do |meridiem|
#         option = { :value => meridiem }
#         option[:selected] = "selected" if selected == meridiem
#         ampm_options << content_tag(:option, label[meridiem], option) + "\n"
#       end
#       build_select(:ampm, ampm_options.join)
#     end
# 
#     private
# 
#     def build_selects_from_types_with_ampm(order)
#       order += [:ampm] if @options[:twelve_hour] and !order.include?(:ampm)
#       build_selects_from_types_without_ampm(order)
#     end
# 
#     alias_method_chain :build_selects_from_types, :ampm
# 
#     def hour12
#       h12 = hour % 12
#       h12 = 12 if h12 == 0
#       return h12
#     end
#   end
# end
