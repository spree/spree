object @variant
cache @variant
extends "spree/api/variants/variant"
child(:images => :images) { extends "spree/api/images/show" }
