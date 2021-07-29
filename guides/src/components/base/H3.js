import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

import HeaderLink from './HeaderLink'

const H3 = ({ children }) => (
  <h3
    id={kebabCase(children)}
    className="flex w-100 relative overflow-visible items-center hide-child b mb2 mt4"
  >
    <HeaderLink text={children}>{children}</HeaderLink>
  </h3>
)

H3.propTypes = {
  children: PropTypes.node.isRequired
}

export default H3
