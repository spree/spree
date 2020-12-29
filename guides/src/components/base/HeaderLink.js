// --- Dependencies
import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

// --- Icons
import IconLink from 'react-feather/dist/icons/link-2'

/**
 * Component
 */

const HeaderLink = ({ text, children }) => (
  <a href={`#${kebabCase(text)}`} className="flex items-center link flex nl4">
    <IconLink className="child pr2" />
    <span className="blue db">{children}</span>
  </a>
)

HeaderLink.propTypes = {
  text: PropTypes.node.isRequired,
  children: PropTypes.node
}

export default HeaderLink
