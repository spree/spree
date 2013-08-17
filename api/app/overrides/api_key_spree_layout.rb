Deface::Override.new(:virtual_path => "spree/layouts/spree_application",
                     :name => "api_key_spree_layout",
                     :insert_bottom => "body",
                     :partial => "spree/api/key",
                     :disabled => false)

