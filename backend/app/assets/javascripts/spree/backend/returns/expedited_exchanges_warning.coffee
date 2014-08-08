$ ->
  $(document).on("change", ".return-items-table .return-item-exchange-selection", ->
    $(".expedited-exchanges-warning").fadeIn()
  )
