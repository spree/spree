$(function() {

  // handle calculating VAT inclusive and exlcusive prices
  // when the opposing value is changed.
  //
  if ($('input#price_including_vat').is('*')) {
    $('input#price_including_vat').change(function(){
      var inc_vat_price = parseFloat($(this).val());

      price = inc_vat_price / (1 + effective_tax_rate);

      $('input#product_price').val(price.toFixed(2));
    });

    $('input#product_price').change(function(){
      var ex_vat_price = parseFloat($(this).val());

      price = ex_vat_price + (ex_vat_price * effective_tax_rate);

      $('input#price_including_vat').val(price.toFixed(2));
    });
  }
});
