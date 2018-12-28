import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

const linkClasses = isActive =>
  `dib mv2 mv0-l link mr2 fw5 f5 nowrap pa2 br2 ${
    isActive ? 'white bg-spree-green fw6' : 'gray'
  }`

const NavItem = ({ url, children, isActive, text }) =>
  url.startsWith('http') ? (
    <a className={linkClasses()} href={url} target="_blank">
      {children}
    </a>
  ) : (
    <span>
      <Link className={linkClasses(isActive)} to={url}>
        {text}
      </Link>
      {children}
    </span>
  )

NavItem.propTypes = {
  url: PropTypes.string.isRequired,
  children: PropTypes.node,
  isActive: PropTypes.bool,
  text: PropTypes.string
}

export default NavItem
