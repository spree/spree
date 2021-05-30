document.addEventListener('DOMContentLoaded', function() {
  document.getElementById('LiveViewSwitcher').addEventListener('click', function (event) {
    if (event.target && event.target.matches("input[type='radio']")) {
      switchLiveViewClass(event.target.id)
    }
  })

  function switchLiveViewClass (value) {
    const liveViewCont = document.getElementById('liveViewCont')

    liveViewCont.classList = ''
    liveViewCont.classList.add(value)
  }
})
