object @variant
cache @variant
extends "spree/api/variants/variant_full"
child(:images => :images) { extends "spree/api/images/show" }
