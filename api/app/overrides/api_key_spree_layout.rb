Deface::Override.new(:virtual_path => "spree/layouts/spree_application",
                     :name => "api_key_spree_layout",
                     :insert_bottom => "body",
                     :partial => "spree/api/key",
                     :disabled => false,
                     :original => "eb4b04993e8e4d1c20a7c3d974dfed20b59aec4c")

