map.set_locale '/locale/set', :controller => 'locale', :action => 'set', :method => :get
map.namespace :admin do |admin|
  admin.resource :localization, :controller => 'admin/localization'
end