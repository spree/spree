Deface::Override.new(:virtual_path => "spree/checkout/registration",
                     :name => "auth_user_login_form",
                     :replace_contents => "[data-hook='registration'] #account, #registration[data-hook] #account",
                     :template => "spree/user_sessions/new",
                     :disabled => false,
                     :original => 'ab20ac9e90baa11b847b30040aef863d2e1af17a')
