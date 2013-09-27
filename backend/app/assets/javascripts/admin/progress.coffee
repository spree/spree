$(document).ready ->
  opts =
    lines: 11
    length: 2
    width: 3
    radius: 9
    corners: 1
    rotate: 0
    color: '#fff'
    speed: 0.8
    trail: 48
    shadow: false
    hwaccel: true
    className: 'spinner'
    zIndex: 2e9
    top: 'auto'
    left: 'auto'

  target = document.getElementById("spinner")

  $(document).ajaxStart ->
    $("#progress").stop(true, true).fadeIn()
    spinner = new Spinner(opts).spin(target)

  $(document).ajaxStop ->
    $("#progress").fadeOut()

