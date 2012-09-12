$(document).ready ->
  opts =
    lines: 11 # The number of lines to draw
    length: 0 # The length of each line
    width: 4 # The line thickness
    radius: 14 # The radius of the inner circle
    corners: 1 # Corner roundness (0..1)
    rotate: 0 # The rotation offset
    color: "#000" # #rgb or #rrggbb
    speed: 0.8 # Rounds per second
    trail: 95 # Afterglow percentage
    shadow: false # Whether to render a shadow
    hwaccel: true # Whether to use hardware acceleration
    className: "spinner" # The CSS class to assign to the spinner
    zIndex: 2e9 # The z-index (defaults to 2000000000)
    top: "auto" # Top position relative to parent in px
    left: "auto" # Left position relative to parent in px

  target = document.getElementById("spinner")  

  $(document).ajaxStart ->
    $("#progress").fadeIn()
    spinner = new Spinner(opts).spin(target)    

  $(document).ajaxStop ->
    $("#progress").fadeOut()    
    
    $('select.select2').select2(
      allowClear: true
    )