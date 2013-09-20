// Init sidebar
$(function() {

  // Add anchor links to headers
  $("#content").find('h2').each(function(){
    $(this).prepend("<a href='#"+$(this).attr("id")+"'><i class='icon-link'></i> ")
  });
  $("#content").find('h3').each(function(){
    $(this).prepend("<a href='#"+$(this).attr("id")+"'><i class='icon-right-open-mini'></i> ")
  });
  $("#content").find('h4').each(function(){
    $(this).prepend("<a href='#"+$(this).attr("id")+"'><i class='icon-dot'></i> ")
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

  sidebar_menu.find('.js-guides li i').on('click', function(){
    if($(this).parent().find('ul:hidden').length > 0){
      $(this).removeClass('icon-right-dir').addClass('icon-down-dir');
      $(this).parent().find('ul').stop().slideDown();
      $(this).parent().removeClass('closed').addClass('opened');
    }
    else if($(this).parent().find('ul:visible')) {
      $(this).removeClass('icon-down-dir').addClass('icon-right-dir');
      $(this).parent().find('ul').stop().slideUp();
      $(this).parent().removeClass('opened').addClass('closed');
    }
  });

  var current_url = window.location.pathname.split('/')[2];
  var active_menu = sidebar_menu.find('a[href="'+current_url+'"]')

  active_menu.addClass('active-open');
  if(active_menu.parent().next().attr('class') == 'js-guides'){
    active_menu.parent().next().show();
  }
  else {
    active_menu.parent().parent().show()
  }

  // TOC
  var current_url = window.location.pathname.split('/')[2];
  var active = sidebar_menu.find('a[href="'+current_url+'"]');
  var toc = active.parent().find('.toc');
  active.parent().addClass('current');
  // if(active.prev().hasClass('icon-dot')){
  //   active.prev().removeClass('icon-dot').addClass('icon-down-dir');
  // }
  toc.toc({
    'container': '#content',
    'anchorName': function(i, heading, prefix) { //custom function for anchor name
      return $(heading).attr('id');
    },
    'smoothScrolling': false
  });

  // $('#sidebar-menu').waypoint('sticky', {
  //   handler: function(){

  //   },
  //   offset: -45
  // });

  // Automatically open sidebar menu depending on section page belongs to
  var current_section = $('meta[name=section]').attr('content');
  $('.toggle-' + current_section + '-menu i').click();
});
