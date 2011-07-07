
var initProductRuleSourceField = function(){

  $products_source_field = jQuery('.products_rule_products_source_field input');
  $products_source_field.click(function() {
    $rule_container = jQuery(this).parents('.promotion-rule');
    if(this.checked){
      if(this.value == 'manual'){
        $rule_container.find('.products_rule_products').show();
        $rule_container.find('.products_rule_product_group').hide();
      } else {
        $rule_container.find('.products_rule_products').hide();
        $rule_container.find('.products_rule_product_group').show();
      }
    }
  });
  $products_source_field.each(function() {
    $(this).triggerHandler('click');
  });

};

var initProductActions = function(){

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
    // Autocomplete product and populate variant select
    $(".promotion_action.create_line_items input[name='add_product_name']").autocomplete("/admin/products.json?authenticity_token=" + $('meta[name=csrf-token]').attr("content"), {
      parse: prep_autocomplete_data,
      formatItem: function(item) {
        return format_autocomplete(item);
      }
    }).result(function(event, data, formatted) {
      if(data){
        // $('#add_product_id').val(data.product.id);
        var url = "/admin/products/" + data.product.permalink + "/variants.json?authenticity_token=" + $('meta[name=csrf-token]').attr("content");
        var $variant_select = $("select[name='add_line_item_variant_id']");
        $variant_select.html('');
        $.getJSON(url, {}, function(variants_data){
          $.each(variants_data, function(){
            $variant_select.append($("<option />").val(this.id).text(this.label));
          });
        });
      }
    }
    );


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
    $(".promotion_action.create_line_items button.add").click(function(){
      var $container = $(this).parents('.promotion_action');
      var product_name = $container.find("input[name='add_product_name']").val();
      var variant_id = $container.find("select[name='add_line_item_variant_id']").val();
      var variant_name = $container.find("select[name='add_line_item_variant_id'] option:selected").text();
      var quantity = $container.find("input[name='add_quantity']").val();
      if(variant_id){
        // Add to the table
        var newRow = "<tr><td>" + product_name + "</td><td>" + variant_name + "</td><td>" + quantity + "</td><td><img src='/admin/images/icons/cross.png' /></td></tr>";
        $container.find('table').append(newRow);
        // Add to serialized string in hidden text field
        var $hiddenField = $container.find("input[type='hidden']");
        $hiddenField.val($hiddenField.val() + "," + variant_id + "x" + quantity);
        setupRemoveLineItems();
        hideOrShowItemTables();
      }
      return false;
    });

  } )();

}

$(document).ready(function() {
  initProductRuleSourceField();
  initProductActions();
});



