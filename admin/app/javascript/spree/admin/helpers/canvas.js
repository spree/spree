// ugly JS copied from a tutorial :)
const initOffcanvas = () => {
  document.querySelectorAll('.pull-bs-canvas-right, .pull-bs-canvas-left').forEach((element) => {
    element.addEventListener('click', () => {
      document.body.insertAdjacentHTML('afterbegin', '<div class="bs-canvas-overlay bg-dark position-fixed w-100 h-100"></div>');
      if(element.classList.contains('pull-bs-canvas-right'))
        document.querySelector('.bs-canvas-right').classList.add('mr-0');
      else
        document.querySelector('.bs-canvas-left').classList.add('ml-0');
    })
  })

  document.querySelectorAll('.bs-canvas-close, .bs-canvas-overlay').forEach((element) => {
    element.addEventListener('click', () => {
      let elm = element.classList.contains('bs-canvas-close') ? element.closest('.bs-canvas') : document.querySelector('.bs-canvas');
      elm.classList.remove('mr-0', 'ml-0');
      document.querySelector('.bs-canvas-overlay').remove();
    })
  })
}

const hideOffcanvas = () => {
  document.querySelector('.bs-canvas')?.classList?.remove('mr-0', 'ml-0');
  document.querySelector('.bs-canvas-overlay')?.remove();
}

document.addEventListener("turbo:load", initOffcanvas)
document.addEventListener("turbo:click", hideOffcanvas)

