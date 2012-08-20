$ ->
  if ($ 'form#update-cart').is('*')
    ($ 'form#update-cart a.delete').show().on 'click' ->
      ($ this).parents('.line-item').first().find('input.line_item_quantity').val 0
      ($ this).parents('form').first().submit()
      false