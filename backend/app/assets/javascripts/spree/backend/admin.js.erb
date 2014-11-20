//= require_self
//= require spree/backend/handlebar_extensions
//= require spree/backend/variant_autocomplete
//= require spree/backend/taxon_autocomplete
//= require spree/backend/option_type_autocomplete
//= require spree/backend/user_picker
//= require spree/backend/product_picker
//= require spree/backend/taxons
//= require spree/backend/jquery.tree-menu

/**
This is a collection of javascript functions and whatnot
under the spree namespace that do stuff we find helpful.
Hopefully, this will evolve into a propper class.
**/

jQuery(function($) {

  // Vertical align of checkbox fields
  $('.field.checkbox label').vAlign()

  // Add some tips
  $('.with-tip').powerTip({
    smartPlacement: true,
    fadeInTime: 50,
    fadeOutTime: 50,
  });

  // Replace ▼ and ▲ in sort_link with nicer icons
  $(".sort_link").each(function(){
    // Remove the &nbsp; in the text
    var sort_link_text = $(this).text().replace('\xA0', '');
    if(sort_link_text.indexOf("▼") >= 0){
      $(this).text(sort_link_text.replace("▼",""));
      $(this).append('<span class="icon icon-chevron-down"></span>');
    } else if(sort_link_text.indexOf("▲") >= 0){
      $(this).text(sort_link_text.replace("▲",""));
      $(this).append('<span class="icon icon-chevron-up"></span>');
    }
  });

  // Enable sidebar toggle
  $("[data-toggle='offcanvas']").click(function(e) {
    e.preventDefault();

    // If window is small enough, enable sidebar push menu
    if ($(window).width() <= 992) {
      $('.row-offcanvas').toggleClass('active');
      $('.left-side').removeClass("collapse-left");
      $(".right-side").removeClass("strech");
      $('.row-offcanvas').toggleClass("relative");
    } else {
      // Else, enable content streching
      $('.left-side').toggleClass("collapse-left");
      $(".right-side").toggleClass("strech");
    }
  });

  $('body')
    .on('powerTipPreRender', '.with-tip', function() {
      $('#powerTip').addClass($(this).data('action'));
      $('#powerTip').addClass($(this).data('tip-color'));
    })
    .on('powerTipClose', '.with-tip', function() {
      $('#powerTip').removeClass($(this).data('action'));
    })

  // Make flash messages dissapear
  setTimeout('$(".alert-auto-dissapear").slideUp()', 5000);

  // Highlight hovered table column
  $('table tbody tr td.actions').find('a, button').hover(function(){
    var tr = $(this).closest('tr');
    var klass = 'highlight action-' + $(this).data('action')
    tr.addClass(klass)
    tr.prev().addClass('before-' + klass);
  }, function(){
    var tr = $(this).closest('tr');
    var klass = 'highlight action-' + $(this).data('action')
    tr.removeClass(klass)
    tr.prev().removeClass('before-' + klass);
  });

  // Trunkate text in page_title that didn't fit
  var truncate_elements = $('.truncate');

  truncate_elements.each(function(){
    $(this).trunk8();
  });
  $(window).resize(function (event) {
    truncate_elements.each(function(){
      $(this).trunk8();
    })
  });

  // Make height of dt/dd elements the same
  $("dl").equalize('outerHeight');

});


$.fn.visible = function(cond) { this[cond ? 'show' : 'hide' ]() };

show_flash = function(type, message) {
  var flash_div = $('.flash.' + type);
  if (flash_div.length == 0) {
    flash_div = $('<div class="alert alert-' + type + '" />');
    $('#main-container').prepend(flash_div);
  }
  flash_div.html(message).show().delay(5000).slideUp();
}


// Apply to individual radio button that makes another element visible when checked
$.fn.radioControlsVisibilityOfElement = function(dependentElementSelector){
  if(!this.get(0)){ return  }
  showValue = this.get(0).value;
  radioGroup = $("input[name='" + this.get(0).name + "']");
  radioGroup.each(function(){
    $(this).click(function(){
      $(dependentElementSelector).visible(this.checked && this.value == showValue)
    });
    if(this.checked){ this.click() }
  });
}

handle_date_picker_fields = function(){
  $('.datepicker').datepicker({
    dateFormat: Spree.translations.date_picker,
    dayNames: Spree.translations.abbr_day_names,
    dayNamesMin: Spree.translations.abbr_day_names,
    firstDay: Spree.translations.first_day,
    monthNames: Spree.translations.month_names,
    prevText: Spree.translations.previous,
    nextText: Spree.translations.next,
    showOn: "focus"
  });

  // Correctly display range dates
  $('.date-range-filter .datepicker-from').datepicker('option', 'onSelect', function(selectedDate) {
    $(".date-range-filter .datepicker-to" ).datepicker( "option", "minDate", selectedDate );
  });
  $('.date-range-filter .datepicker-to').datepicker('option', 'onSelect', function(selectedDate) {
    $(".date-range-filter .datepicker-from" ).datepicker( "option", "maxDate", selectedDate );
  });
}

$(document).ready(function(){
  handle_date_picker_fields();
  $(".observe_field").on('change', function() {
    target = $(this).data("update");
    $(target).hide();
    $.ajax({ dataType: 'html',
             url: $(this).data("base-url")+encodeURIComponent($(this).val()),
             type: 'get',
             success: function(data){
               $(target).html(data);
               $(target).show();
             }
    });
  });
  var uniqueId = 1;
  $('.spree_add_fields').click(function() {
    var target = $(this).data("target");
    var new_table_row = $(target + ' tr:visible:last').clone();
    var new_id = new Date().getTime() + (uniqueId++);
    new_table_row.find("input, select").each(function () {
      var el = $(this);
      el.val("");
      el.prop("id", el.prop("id").replace(/\d+/, new_id))
      el.prop("name", el.prop("name").replace(/\d+/, new_id))
    })
    // When cloning a new row, set the href of all icons to be an empty "#"
    // This is so that clicking on them does not perform the actions for the
    // duplicated row
    new_table_row.find("a").each(function () {
      var el = $(this);
      el.prop('href', '#');
    })
    $(target).prepend(new_table_row);
  })

  $('body').on('click', '.delete-resource', function() {
    var el = $(this);
    if (confirm(el.data("confirm"))) {
      $.ajax({
        type: 'POST',
        url: $(this).prop("href"),
        data: {
          _method: 'delete',
          authenticity_token: AUTH_TOKEN
        },
        dataType: 'script',
        success: function(response) {
          el.parents("tr").fadeOut('hide', function() {
            $(this).remove();
          });
        },
        error: function(response, textStatus, errorThrown) {
          show_flash('error', response.responseText);
        }
      });
    }
    return false;
  });

  $('body').on('click', 'a.spree_remove_fields', function() {
    el = $(this);
    el.prev("input[type=hidden]").val("1");
    el.closest(".fields").hide();
    if (el.prop("href").substr(-1) == '#') {
      el.parents("tr").fadeOut('hide');
    }else if (el.prop("href")) {
      $.ajax({
        type: 'POST',
        url: el.prop("href"),
        data: {
          _method: 'delete',
          authenticity_token: AUTH_TOKEN
        },
        success: function(response) {
          el.parents("tr").fadeOut('hide');
        },
        error: function(response, textStatus, errorThrown) {
          show_flash('error', response.responseText);
        }

      })
    }
    return false;
  });

  $('body').on('click', '.select_properties_from_prototype', function(){
    $("#busy_indicator").show();
    var clicked_link = $(this);
    $.ajax({ dataType: 'script', url: clicked_link.prop("href"), type: 'get',
        success: function(data){
          clicked_link.parent("td").parent("tr").hide();
          $("#busy_indicator").hide();
        }
    });
    return false;
  });

  // Fix sortable helper
  var fixHelper = function(e, ui) {
      ui.children().each(function() {
          $(this).width($(this).width());
      });
      return ui;
  };

  $('table.sortable').ready(function(){
    var td_count = $(this).find('tbody tr:first-child td').length
    $('table.sortable tbody').sortable(
      {
        handle: '.handle',
        helper: fixHelper,
        placeholder: 'ui-sortable-placeholder',
        update: function(event, ui) {
          $("#progress").show();
          positions = {};
          $.each($('table.sortable tbody tr'), function(position, obj){
            reg = /spree_(\w+_?)+_(\d+)/;
            parts = reg.exec($(obj).prop('id'));
            if (parts) {
              positions['positions['+parts[2]+']'] = position;
            }
          });
          $.ajax({
            type: 'POST',
            dataType: 'script',
            url: $(ui.item).closest("table.sortable").data("sortable-link"),
            data: positions,
            success: function(data){ $("#progress").hide(); }
          });
        },
        start: function (event, ui) {
          // Set correct height for placehoder (from dragged tr)
          ui.placeholder.height(ui.item.height())
          // Fix placeholder content to make it correct width
          ui.placeholder.html("<td colspan='"+(td_count-1)+"'></td><td class='actions'></td>")
        },
        stop: function (event, ui) {
          // Fix odd/even classes after reorder
          $("table.sortable tr:even").removeClass("odd even").addClass("even");
          $("table.sortable tr:odd").removeClass("odd even").addClass("odd");
        }

      });
  });

  $('a.dismiss').click(function() {
    $(this).parent().fadeOut();
  });

  window.Spree.advanceOrder = function() {
      $.ajax({
          type: "PUT",
          async: false,
          url: Spree.url(Spree.routes.checkouts_api + "/" + order_number + "/advance")
      }).done(function() {
          window.location.reload();
      });
  }
});
