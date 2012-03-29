object @variant
extends "spree/api/v1/variants/_variant"
child(:option_values => :option_values) { attributes *option_value_attributes }
