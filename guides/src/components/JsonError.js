import * as React from 'react'
import PropTypes from 'prop-types'

const JsonError = ({ children }) => (
  <div
    css={{
      backgroundColor: 'red',
      color: 'white',
      lineHeight: '1.5'
    }}
  >
    {children}
  </div>
)

export default JsonError
