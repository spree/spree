import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

import HeaderLink from './HeaderLink'

const H1 = ({ children }) => (
  <h1
    id={kebabCase(children)}
    className="pt4 nt4 flex w-100 relative overflow-visible items-center hide-child f2 fw5"
  >
    <HeaderLink text={children}>{children}</HeaderLink>
  </h1>
)

H1.propTypes = {
  children: PropTypes.node.isRequired
}

export default H1
