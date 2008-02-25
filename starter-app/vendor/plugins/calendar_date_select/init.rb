%w[calendar_date_select includes_helper].each { |file| 
  require File.join( File.dirname(__FILE__), "lib",file) 
}

ActionView::Helpers::FormHelper.send(:include, CalendarDateSelect::FormHelper)
ActionView::Base.send(:include, CalendarDateSelect::FormHelper)
ActionView::Base.send(:include, CalendarDateSelect::IncludesHelper)

# install files
['/public/javascripts/calendar_date_select', '/public/stylesheets/calendar_date_select', '/public/images/calendar_date_select'].each{|dir|
  source = File.join(directory,dir)
  dest = RAILS_ROOT + dir
  FileUtils.mkdir_p(dest)
  FileUtils.cp_r(Dir.glob(source+'/*.*'), dest)
} unless File.exists?(RAILS_ROOT + '/public/javascripts/calendar_date_select/calendar_date_select.js')
