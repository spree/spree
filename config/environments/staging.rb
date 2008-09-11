# This is just used for performance testing
config.cache_classes = true
config.action_controller.consider_all_requests_local = false
config.action_controller.perform_caching             = true
config.action_view.cache_template_loading            = true

config.log_level = :debug

config.action_controller.session = { :session_key => "_myapp_session", :secret => "f83596f6af70839845325108d3d4f42df4c64a605a4d805ecb636ba4dc42d41b1f7b179d47aaf1c3a4993f0941908b0d7c6e8d214578a0d9b77a30a9a8657ed5" }

# prevents rails 2.1 from complaining about protect_from_forgery while profiling
config.action_controller.allow_forgery_protection = false 

