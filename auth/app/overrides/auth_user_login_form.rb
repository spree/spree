Deface::Override.new(:virtual_path => "spree/checkout/registration",
                     :name => "auth_user_login_form",
                     :replace_contents => "[data-hook='registration'] #account, #registration[data-hook] #account",
                     :template => "spree/user_sessions/new",
                     :disabled => false)
