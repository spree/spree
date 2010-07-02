map.namespace :admin do |admin|
  admin.resources :promotions, :has_many => :promotion_rules
end
