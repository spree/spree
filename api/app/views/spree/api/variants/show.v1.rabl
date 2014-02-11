object @variant
cache @variant
extends "spree/api/variants/big_variant"
child(:images => :images) { extends "spree/api/images/show" }
