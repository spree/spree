if Rails::VERSION::STRING >= '6.1'
  ActiveRecord::Base.has_many_inversing = false
end
