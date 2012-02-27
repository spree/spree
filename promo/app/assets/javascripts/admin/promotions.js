var initProductActions = function(){

  $("#add_product_name").product_autocomplete();

  $('.calculator-fields').each(function(){
    var $fields_container = $(this);
    var $type_select = $fields_container.find('.type-select');
    var $settings = $fields_container.find('.settings');
    var $warning = $fields_container.find('.warning');
    var originalType = $type_select.val();

    $warning.hide();
    $type_select.change(function(){
      if( $(this).val() == originalType ){
        $warning.hide();
        $settings.show();
        $settings.find('input').removeAttr('disabled');
      } else {
        $warning.show();
        $settings.hide();
        $settings.find('input').attr('disabled', 'disabled');
      }
    });
  });

  //
  // CreateLineItems Promotion Action
  //
  ( function(){
    var hideOrShowItemTables = function(){
      $('.promotion_action table').each(function(){
        if($(this).find('td').length == 0){
          $(this).hide();
        } else {
          $(this).show();
        }
      });
    };
    hideOrShowItemTables();

    // Remove line item
    var setupRemoveLineItems = function(){
      $(".promotion_action.create_line_items table img").unbind('click').click(function(){
        var $container = $(this).parents('.promotion_action');
        var $hiddenField = $container.find("input[type='hidden']");
        var $row = $(this).parents('tr');
        var index = $row.parents('table').find('tr').index($row.get(0));
        // Remove variant_id quantity pair from the string
        var items = _($hiddenField.val().split(',')).compact();
        items.splice(index - 1, 1);
        $hiddenField.val(items.join(','));
        $(this).parents('tr').remove();
        hideOrShowItemTables();
      });
    };
    setupRemoveLineItems();
    // Add line item to list
    $(".promotion_action.create_line_items button.add").unbind('click').click(function(e){
      var $container = $(this).parents('.promotion_action');
      var product_name = $container.find("input[name='add_product_name']").val();
      var variant_id = $container.find("input[name='add_variant_id']").val();
      var quantity = $container.find("input[name='add_quantity']").val();
      if(variant_id){
        // Add to the table
        var newRow = "<tr><td>" + product_name + "</td><td>" + quantity + "</td><td><img src='/assets/admin/icons/cross.png' /></td></tr>";
        $container.find('table').append(newRow);
        // Add to serialized string in hidden text field
        var $hiddenField = $container.find(".line_items_string");
        $hiddenField.val($hiddenField.val() + "," + variant_id + "x" + quantity);
        setupRemoveLineItems();
        hideOrShowItemTables();
      }
      return false;
    });

  } )();

}

$(document).ready(function() {
  initProductActions();

  // toggle fields for specific events
  $('#promotion_event_name').change(function() {
    $('#promotion_code_field').toggle($('#promotion_event_name').val() == 'spree.checkout.coupon_code_added');
    $('#promotion_path_field').toggle($('#promotion_event_name').val() == 'spree.content.visited');
  });
  $('#promotion_event_name').change();

});



