import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

const linkClasses = isActive =>
  `dib mv2 mv0-l link mr3 fw4 f4 nowrap ${
    isActive ? 'spree-green' : 'dark-gray'
  }`

const NavItem = ({ url, children, isActive, text }) => {
  if (url.startsWith('http')) {
    return (
      <a className={linkClasses()} href={url} target="_blank">
        {children}
      </a>
    )
  } else {
    return (
      <span>
        <Link className={linkClasses(isActive)} to={url}>
          {text}
        </Link>
        {children}
      </span>
    )
  }
}

NavItem.propTypes = {
  url: PropTypes.string.isRequired,
  children: PropTypes.node,
  isActive: PropTypes.bool,
  text: PropTypes.string
}

export default NavItem
