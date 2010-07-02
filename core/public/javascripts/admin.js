/**
This is a collection of javascript functions and whatnot
under the spree namespace that do stuff we find helpful.
Hopefully, this will evolve into a propper class.
**/

var spree;
if (!spree) spree = {};

jQuery.noConflict() ;

jQuery(document).ajaxStart(function(){
  jQuery("#progress").slideDown();
});

jQuery(document).ajaxStop(function(){
  jQuery("#progress").slideUp();
});

jQuery.fn.visible = function(cond) { this[cond ? 'show' : 'hide' ]() };

// Apply to individual radio button that makes another element visible when checked
jQuery.fn.radioControlsVisibilityOfElement = function(dependentElementSelector){
  if(!this.get(0)){ return  }
  showValue = this.get(0).value;
  radioGroup = $("input[name='" + this.get(0).name + "']");
  radioGroup.each(function(){
    jQuery(this).click(function(){
      jQuery(dependentElementSelector).visible(this.checked && this.value == showValue)
    });
    if(this.checked){ this.click() }
  });
}

var request = function(options) {
  jQuery.ajax(jQuery.extend({ dataType: 'script', url: options.url, type: 'get' }, options));
  return false;
};
 
// remote links handler
jQuery('a[data-remote=true]').live('click', function() {
  if(method = jQuery(this).attr("data-method")){
    return request({ url: this.href, type: 'POST', data: {'_method': method} });
  } else {
    return request({ url: this.href });
  }
});
 
// remote forms handler
jQuery('form[data-remote=true]').live('submit', function() {
  return request({ url : this.action, type : this.method, data : jQuery(this).serialize() });
});




// Product autocompletion
image_html = function(item){
  return "<img src='/assets/products/" + item['images'][0]["id"] + "/mini/" + item['images'][0]['attachment_file_name'] + "'/>";
}

format_autocomplete = function(data){
  var html = "";

  var product = data['product'];

  if(data['variant']==undefined){
    // product

    if(product['images'].length!=0){
      html = image_html(product);
    }

    html += "<div><h4>" + product['name'] + "</h4>";
    html += "<span><strong>Sku: </strong>" + product['master']['sku'] + "</span>";
    html += "<span><strong>On Hand: </strong>" + product['count_on_hand'] + "</span></div>";
  }else{
    // variant
    var variant = data['variant'];
    var name = product['name'];

    if(variant['images'].length!=0){
      html = image_html(variant);
    }else{
      if(product['images'].length!=0){
        html = image_html(product);
      }
    }

    name += " - " + $.map(variant['option_values'], function(option_value){
      return option_value["option_type"]["presentation"] + ": " + option_value['name'];
    }).join(", ")

    html += "<div><h4>" + name + "</h4>";
    html += "<span><strong>Sku: </strong>" + variant['sku'] + "</span>";
    html += "<span><strong>On Hand: </strong>" + variant['count_on_hand'] + "</span></div>";
  }


  return html
}


prep_autocomplete_data = function(data){
  return $.map(eval(data), function(row) {

    var product = row['product'];

    if(product['variants'].length>0 && expand_variants){
      //variants
      return $.map(product['variants'], function(variant){

        var name = product['name'];
        name += " - " + $.map(variant['option_values'], function(option_value){
          return option_value["option_type"]["presentation"] + ": " + option_value['name'];
        }).join(", ");

        return {
            data: {product: product, variant: variant},
            value: name,
            result: name
        }
      });
    }else{
      return {
          data: {product: product},
          value: product['name'],
          result: product['name']
      }
    }
  });
}

jQuery.fn.product_autocomplete = function(){
  $(this).autocomplete("/admin/products.json", {
      parse: prep_autocomplete_data,
      formatItem: function(item) {
        return format_autocomplete(item);
      }
    }).result(function(event, data, formatted) {
      if (data){
        if(data['variant']==undefined){
          // product
          $('#add_variant_id').val(data['product']['master']['id']);
        }else{
          // variant
          $('#add_variant_id').val(data['variant']['id']);
        }
      }
    });
}



jQuery.fn.objectPicker = function(url){
  jQuery(this).tokenInput(url, {
    searchDelay          : 600,
    hintText             : strings.type_to_search,
    noResultsText        : strings.no_results,
    searchingText        : strings.searching,
    prePopulateFromInput : true
  });
};

jQuery.fn.productPicker = function(){
  jQuery(this).objectPicker(ajax_urls.product_search_basic_json);
}
jQuery.fn.userPicker = function(){
  jQuery(this).objectPicker(ajax_urls.user_search_basic_json);
}

jQuery(document).ready(function() {

  jQuery('.tokeninput.products').productPicker();
  jQuery('.tokeninput.users').userPicker();

});
