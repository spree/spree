$ ->
  ($ 'input[type=checkbox]:not(:checked)').attr 'disabled', true  if ($ '.categories input:checked').length > 0
  categoryCheckboxes = '.categories input[type=checkbox]'
  $(categoryCheckboxes).change ->
    if ($ this).is(':checked')
      ($ categoryCheckboxes + ':not(:checked)').attr 'disabled', true
      ($ this).removeAttr 'disabled'
    else
      ($ 'input[type=checkbox]').removeAttr 'disabled'

