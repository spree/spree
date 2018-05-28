/**
This is a collection of javascript functions and whatnot
under the spree namespace that do stuff we find helpful.
Hopefully, this will evolve into a propper class.
**/

jQuery(function($) {

  // Add some tips
  $('.with-tip').tooltip();

  $('.js-show-index-filters').click(function(){
    $(".filter-well").slideToggle();
    $(this).parents(".filter-wrap").toggleClass("collapsed");
    $("span.icon", $(this)).toggleClass("icon-chevron-down");
  });

  $('#main-sidebar').find('[data-toggle="collapse"]').on('click', function()
    {
      if($(this).find('.icon-chevron-left').length == 1){
        $(this).find('.icon-chevron-left').removeClass('icon-chevron-left').addClass('icon-chevron-down');
      }
      else {
        $(this).find('.icon-chevron-down').removeClass('icon-chevron-down').addClass('icon-chevron-left');
      }
    }
  )

  // Sidebar nav toggle functionality
  var sidebar_toggle = $('#sidebar-toggle');
  sidebar_toggle.on('click', function() {
    var wrapper = $('#wrapper');
    var main    = $('#main-part');
    var sidebar = $('#main-sidebar');

    // these should match `spree/backend/app/helpers/spree/admin/navigation_helper.rb#main_part_classes`
    var mainWrapperCollapsedClasses = 'col-xs-12 sidebar-collapsed';
    var mainWrapperExpandedClasses = 'col-xs-9 col-xs-offset-3 col-md-10 col-md-offset-2';

    wrapper.toggleClass('sidebar-minimized');
    sidebar.toggleClass('hidden-xs');
    main
      .toggleClass(mainWrapperCollapsedClasses)
      .toggleClass(mainWrapperExpandedClasses);

    if (wrapper.hasClass('sidebar-minimized')) {
      Cookies.set('sidebar-minimized', 'true', { path: '/admin' });
    } else {
      Cookies.set('sidebar-minimized', 'false', { path: '/admin' });
    }
  });

  $('.sidebar-menu-item').mouseover(function(){
    if($('#wrapper').hasClass('sidebar-minimized')){
      $(this).addClass('menu-active');
      $(this).find('ul.nav').addClass('submenu-active');
    }
  });
  $('.sidebar-menu-item').mouseout(function(){
    if($('#wrapper').hasClass('sidebar-minimized')){
      $(this).removeClass('menu-active');
      $(this).find('ul.nav').removeClass('submenu-active');
    }
  });

  // TODO: remove this js temp behaviour and fix this decent
  // Temp quick search
  // When there was a search term, copy it
  $(".js-quick-search").val($(".js-quick-search-target").val());
  // Catch the quick search form submit and submit the real form
  $("#quick-search").submit(function(){
    $(".js-quick-search-target").val($(".js-quick-search").val());
    $("#table-filter form").submit();
    return false;
  });

  // Main menu active item submenu show
  var active_item = $('#main-sidebar').find('.selected');
  active_item.closest('.nav-pills').addClass('in');
  active_item.closest('.nav-sidebar')
    .find('.icon-chevron-left')
    .removeClass('icon-chevron-left')
    .addClass('icon-chevron-down');

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

  // Clickable ransack filters
  $(".js-add-filter").click(function() {
    var ransack_field = $(this).data("ransack-field");
    var ransack_value = $(this).data("ransack-value");

    $("#" + ransack_field).val(ransack_value);
    $("#table-filter form").submit();
  });

  $(document).on("click", ".js-delete-filter", function() {
    var ransack_field = $(this).parents(".js-filter").data("ransack-field");

    $("#" + ransack_field).val('');
    $("#table-filter form").submit();
  });

  $(".js-filterable").each(function() {
    var $this = $(this);

    if ($this.val()) {
      var ransack_value, filter;
      var ransack_field = $this.attr("id");
      var label = $('label[for="' + ransack_field + '"]');

      if ($this.is("select")) {
        ransack_value = $this.find('option:selected').text();
      } else {
        ransack_value = $this.val();
      }

      label = label.text() + ': ' + ransack_value;
      filter = '<span class="js-filter label label-default" data-ransack-field="' + ransack_field + '">' + label + '<span class="icon icon-delete js-delete-filter"></span></span>';

      $(".js-filters").append(filter).show();
    }
  });

  // per page dropdown
  // preserves all selected filters / queries supplied by user
  // changes only per_page value
  $(".js-per-page-select").change(function() {
    var form  = $(this).closest(".js-per-page-form");
    var url   = form.attr('action');
    var value = $(this).val().toString();
    if (url.match(/\?/)) {
      url += "&per_page=" + value;
    } else {
      url += "?per_page=" + value;
    }
    window.location = url;
  });

  // injects per_page settings to all available search forms
  // so when user changes some filters / queries per_page is preserved
  $(document).ready(function() {
    var perPageDropdown = $(".js-per-page-select:first");
    if (perPageDropdown.length) {
      var perPageValue = perPageDropdown.val().toString();
      var perPageInput = '<input type="hidden" name="per_page" value=' + perPageValue + ' />';
      $("#table-filter form").append(perPageInput);
    }
  });

  // Make flash messages disappear
  setTimeout('$(".alert-auto-disappear").slideUp()', 5000);

});


$.fn.visible = function(cond) { this[cond ? 'show' : 'hide' ]() };

show_flash = function(type, message) {
  var flash_div = $('.alert-' + type);
  if (flash_div.length == 0) {
    flash_div = $('<div class="alert alert-' + type + '" />');
    $('#content').prepend(flash_div);
  }
  flash_div.html(message).show().delay(10000).slideUp();
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
          var $flash_element = $('.alert-success');
          if ($flash_element.length) {
            el.parents("tr").fadeOut('hide', function() {
              $(this).remove();
            });
          }
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
          el.parents("tr").fadeOut('hide', function() {
            $(this).remove();
          });
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
          var tbody = this;
          $("#progress").show();
          positions = {};
          $.each($('tr', tbody), function(position, obj){
            reg = /spree_(\w+_?)+_(\d+)/;
            parts = reg.exec($(obj).prop('id'));
            if (parts) {
              positions['positions['+parts[2]+']'] = position+1;
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
          data: {
            token: Spree.api_key
          },
          url: Spree.url(Spree.routes.checkouts_api + "/" + order_number + "/advance")
      }).done(function() {
          window.location.reload();
      });
  }
});
