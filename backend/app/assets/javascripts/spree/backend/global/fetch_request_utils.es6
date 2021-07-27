/* eslint-disable no-undef */
/* eslint-disable no-unused-vars */

const showProgressIndicator = () => {
  const progressBar = document.querySelector('#progress')
  progressBar.classList.add('d-block')
  animateCSS('#progress', 'fadeInUp', 'faster')
}

const hideProgressIndicator = () => {
  const progressBar = document.querySelector('#progress')
  animateCSS('#progress', 'fadeOutDown', 'faster')

  progressBar.addEventListener('animationend', () => {
    progressBar.classList.remove('d-block')
  })
}

const animateCSS = (element, animation, speed, prefix = 'animate__') =>
  // We create a Promise and return it
  new Promise((resolve) => {
    const animationName = `${prefix}${animation}`
    const node = document.querySelector(element)

    node.classList.add(`${prefix}animated`, animationName, prefix + speed);

    // When the animation ends, we clean the classes and resolve the Promise
    function handleAnimationEnd(event) {
      event.stopPropagation()
      node.classList.remove(`${prefix}animated`, animationName)
      resolve('Animation ended')
    }

    node.addEventListener('animationend', handleAnimationEnd, { once: true })
  })

const spreeHandleResponse = function(response, handleError = true) {
  hideProgressIndicator()

  if (!response.ok && handleError === true) show_flash('info', response.statusText)

  return response.json()
}
