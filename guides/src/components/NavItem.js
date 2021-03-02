// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'

/**
 * Helpers
 */

const linkClasses = isActive =>
  `bb-l bw2-l dib flex-l items-center-l h-100-l mv2 mv0-l link mr0 f5 nowrap pa2 ${
    isActive
      ? 'b--spree-green spree-green b--gray w-100 w-auto-l fw7'
      : 'gray b--transparent fw5'
  }`

/**
 * Component
 */

const NavItem = ({ url, children, isActive, text, title }) =>
  url.startsWith('http') ? (
    <a className={linkClasses()} href={url} target="_blank" title={title}>
      {children}
    </a>
  ) : (
    <span className="dib h-100">
      <Link className={linkClasses(isActive)} to={url} title={title}>
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
