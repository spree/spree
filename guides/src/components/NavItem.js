// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

/**
 * Helpers
 */

const linkClasses = isActive =>
  `bb-l bw2-l h-100 inline-flex items-center link fw5 f5 nowrap ph2 ${
    isActive
      ? 'b--spree-green spree-green b--gray w-100 w-auto-l'
      : 'gray b--transparent'
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
    <span className="dib h-100">
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
