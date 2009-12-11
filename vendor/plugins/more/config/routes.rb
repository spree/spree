ActionController::Routing::Routes.draw do |map|
  map.connect "#{Less::More.destination_path}/*id.css", :controller => 'less_cache', :action => "show"
end