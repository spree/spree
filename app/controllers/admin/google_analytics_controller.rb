class Admin::GoogleAnalyticsController < Admin::BaseController
  resource_controller
  create.response do |wants|
    wants.html {redirect_to collection_url}
  end
  destroy.response do |wants|
    wants.html {redirect_to collection_url}
  end
end
