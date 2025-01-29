const initNavs = () => {
  document.querySelectorAll('#settings-nav .nav-link').forEach((element) => {
    element.addEventListener('click', () => {
      element.parentElement.parentElement.querySelectorAll('.nav-link.active').forEach((element) => {
        element.classList.remove('active')
      })
    })
  })
}
document.addEventListener("turbo:load", initNavs)
