object @variant
extends "spree/api/v1/variants/variant"
child(:option_values => :option_values) { attributes *option_value_attributes }
