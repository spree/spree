object @variant
cache ['show', root_object]
extends "spree/api/variants/variant_full"
child(:images => :images) { extends "spree/api/images/show" }
