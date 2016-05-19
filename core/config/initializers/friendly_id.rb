# To learn more, check out the guide:
# http://norman.github.io/friendly_id/file.Guide.html
FriendlyId.defaults do |config|
  config.use :reserved
  config.reserved_words = %w(new edit index session login logout users admin
                             stylesheets assets javascripts images)
end
