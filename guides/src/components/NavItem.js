// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

/**
 * Helpers
 */

const linkClasses = isActive =>
  `dib mv2 mv0-l link mr2-l mr0 fw5 f5 nowrap pv2 ph1 ph2-l ${
    isActive
      ? 'white bg-spree-green fw6 br2-l ph3 ph1-l w-100 w-auto-l'
      : 'gray'
  }`

/**
 * Component
 */

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
