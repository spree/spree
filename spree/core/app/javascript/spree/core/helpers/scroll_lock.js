export function lockScroll() {
  const body = document.body
  const scrollPosition = window.scrollY || body.scrollTop
  document.documentElement.style.setProperty('--scroll-y', scrollPosition)

  body.style.top = `-${scrollPosition}px`
  const scrollbarWidth = window.innerWidth - document.documentElement.clientWidth
  document.body.style.paddingRight = `${scrollbarWidth}px`
  body.style.left = '0px'
  body.style.right = '0px'
  body.style.overflow = 'hidden'
  body.style.position = 'fixed'
}

export function unlockScroll() {
  const body = document.body
  body.style.position = ''
  body.style.paddingRight = ''
  body.style.left = ''
  body.style.right = ''
  body.style.overflow = ''

  document.documentElement.scrollTop = document.documentElement.style.getPropertyValue('--scroll-y') || window.scrollY
  body.style.top = ''
}
