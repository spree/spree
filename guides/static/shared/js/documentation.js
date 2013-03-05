// Init sidebar
$(function() {

  // Add anchor links to headers
  $("#content").find('h1, h2, h3').each(function(){
    $(this).prepend("<a href='#"+$(this).attr("id")+"'><i clas='icon-link'><i> ")
  });

  // Sidebar menu
  var sidebar_menu = $("#sidebar-menu")

  sidebar_menu.find('h3 a.js-expand-btn').click(function(e){
    e.preventDefault();
    var icon = $(this).find('i');

    if(icon.attr('class') == 'icon-right-open'){
      icon.removeClass('icon-right-open').addClass('icon-down-open');
      sidebar_menu.find('a.active').removeClass('active');
      icon.parent().next().addClass('active');
      icon.parent().parent().next().stop().slideDown();
    }
    else{
      icon.removeClass('icon-down-open').addClass('icon-right-open');
      sidebar_menu.find('a.active').removeClass('active');
      icon.parent().parent().next().stop().slideUp();
    }
  });

  sidebar_menu.find('.js-guides li i').toggle(function(){
    if($(this).parent().find('ul').length > 0){
      $(this).removeClass('icon-right-dir').addClass('icon-down-dir');
      $(this).parent().find('ul').stop().slideDown();
    }
  }, function(){
    if($(this).parent().find('ul').length > 0){
      $(this).removeClass('icon-down-dir').addClass('icon-right-dir');
      $(this).parent().find('ul').stop().slideUp();
    }
  });

  var current_url = window.location.pathname

  var active_menu = sidebar_menu.find('a[href="'+current_url+'"]')
  active_menu.addClass('active-open');
  if(active_menu.parent().next().attr('class') == 'js-guides'){
    active_menu.parent().next().show();
    active_menu.prev().find('i.icon-right-open').removeClass('icon-right-open').addClass('icon-down-open')
  }
  else {
    active_menu.parent().parent().show()
  }

});
