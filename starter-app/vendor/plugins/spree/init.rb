# libs
require_dependency 'constants/enumerable_constants'
require_dependency 'gateway/bogus_gateway'

# see the following post for explanation (http://www.ruby-forum.com/topic/137733)
if ENV['RAILS_ENV'] == 'development'
  load_paths.each do |path|  
    "puts reloading ..."
    Dependencies.load_once_paths.delete(path)
  end
end