/**
This is a collection of javascript functions and whatnot
under the spree namespace that do stuff we find helpful.
Hopefully, this will evolve into a propper class.
**/

var spree;
if (!spree) spree = {};

$ = jQuery;
$j = jQuery;

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
  $.ajax($.extend({ url : options.url, type : 'get' }, options));
  return false;
};

// remote links handler
$('a[data-ujs=true]').live('click', function() {
  if(confirm_msg = $(this).attr("data-confirm")){
    if (!confirm(confirm_msg)) return false;
  }
  if(method = $(this).attr("data-method")){
    return request({ url: this.href, type: 'POST', data: {'_method': method} });
  } else {
    update_target = $(this).attr("data-update");
    link_container = $(this).parent();
    if (update_target) {
      if ($("#"+update_target).length == 0) {
        if ($("#"+update_target.replace('_', '-')).length > 0) {
          update_target = update_target.replace('_', '-')
        } else {
          alert("<div id="+update_target+"></div> not found, add it to view to allow AJAX request.");
          return true;
        }
      }
    }

    $.ajax({
      url: this.href,
      dataType: 'html',
      type: 'GET',
      success: function(data) {
        if (update_target) {
          $("#"+update_target).html(data);
          link_container.hide();
        }
      }
    });

    return false;
  }
});

// remote forms handler
$('form[data-remote=true]').live('submit', function() {
  return request({ url : this.action, type : this.method, data : $(this).serialize() });
});




// Product autocompletion
image_html = function(item){
  return "<img src='/assets/products/" + item['images'][0]["id"] + "/mini/" + item['images'][0]['attachment_file_name'] + "'/>";
}

format_product_autocomplete = function(data){
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


prep_product_autocomplete_data = function(data){
  return $.map(eval(data), function(row) {

    var product = row['product'];

    if(product['variants'].length>0 && ['expand_variants']){
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
  $(this).autocomplete("/admin/products.json?authenticity_token=" + $('meta[name=csrf-token]').attr("content"), {
      parse: prep_product_autocomplete_data,
      formatItem: function(item) {
        return format_product_autocomplete(item);
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
  jQuery(this).tokenInput(url + "&authenticity_token=" + AUTH_TOKEN, {
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

function add_fields(target, association, content) {
  var new_id = new Date().getTime();
  var regexp = new RegExp("new_" + association, "g");
  $(target).append(content.replace(regexp, new_id));
}

jQuery('a.remove_fields').live('click', function() {
  $(this).prev("input[type=hidden]").val("1");
  $(this).closest(".fields").hide();
  return false;
});

// admin states changes handler
$(".observe_field").live('change', function() {
  target = $(this).attr("data-update");
  ajax_indicator = $(this).attr("data-ajax-indicator") || '#busy_indicator';
  $(target).hide();
  $(ajax_indicator).show();
  $.ajax({
    url: $(this).attr("data-base-url")+encodeURIComponent($(this).val()),
    dataType: 'html',
    success: function(data) {
      $(target).html(data);
      $(ajax_indicator).hide();
      $(target).show();
    }
  });
});