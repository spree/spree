import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

import HeaderLink from './HeaderLink'

const H2 = ({ children }) => (
  <h2
    id={kebabCase(children)}
    className="mt0 flex w-100 relative overflow-visible items-center hide-child f3 fw4"
  >
    <HeaderLink text={children}>{children}</HeaderLink>
  </h2>
)

H2.propTypes = {
  children: PropTypes.node.isRequired
}

export default H2
