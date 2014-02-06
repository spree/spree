object @variant
cache [__FILE__.gsub(/.*app\/views/, ""), root_object]

extends "spree/api/variants/variant"
child(:images => :images) { extends "spree/api/images/show" }
