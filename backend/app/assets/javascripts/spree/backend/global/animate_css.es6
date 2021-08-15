/* eslint-disable no-unused-vars */

//
// Handle clearing out of animation styles from complete animation.
const animateCSS = (element, animation, speed, prefix = 'animate__') =>
  new Promise((resolve) => {
    const animationName = `${prefix}${animation}`
    const node = document.querySelector(element)

    node.classList.add(`${prefix}animated`, animationName, prefix + speed)

    function handleAnimationEnd(event) {
      event.stopPropagation()
      node.classList.remove(`${prefix}animated`, animationName)
      resolve('Animation ended')
    }

    node.addEventListener('animationend', handleAnimationEnd, { once: true })
  })
