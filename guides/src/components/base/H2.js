import * as React from 'react'
import PropTypes from 'prop-types'
import kebabCase from 'lodash.kebabcase'

import HeaderLink from './HeaderLink'

import v from '../../utils/styles'

const H2 = ({ children }) => (
  <h2
    css={{ paddingTop: v.linkOffset, marginTop: `-${v.linkOffset}` }}
    id={kebabCase(children)}
    className="flex w-100 relative overflow-visible items-center hide-child f3 fw5"
  >
    <HeaderLink text={children}>{children}</HeaderLink>
  </h2>
)

H2.propTypes = {
  children: PropTypes.node.isRequired
}

export default H2
