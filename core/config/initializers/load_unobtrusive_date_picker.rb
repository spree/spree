require '12_hour_time'
require 'unobtrusive_date_picker'

# Include all the necessary functions in to the appropriate point in the Rails framework
ActionView::Base.send :include, UnobtrusiveDatePicker::UnobtrusiveDatePickerHelper
ActionView::Helpers::DateHelper.send :include, UnobtrusiveDatePicker::UnobtrusiveDatePickerHelper
ActionView::Base.send :include, UnobtrusiveDatePicker::AssetTagHelper
ActionView::Helpers::AssetTagHelper.send :include, UnobtrusiveDatePicker::AssetTagHelper
