// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

// --- Components
import HeaderLink from './HeaderLink'

/**
 * Component
 */

const H4 = ({ children }) => (
  <h4
    id={kebabCase(children)}
    className="flex fw4 w-100 relative overflow-visible items-center hide-child f5"
  >
    <HeaderLink text={children}>{children}</HeaderLink>
  </h4>
)

H4.propTypes = {
  children: PropTypes.node.isRequired
}

export default H4
