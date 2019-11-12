// --- Dependencies
/** @jsx jsx */
import PropTypes from 'prop-types'
import { css, jsx } from '@emotion/core'

/**
 * Styles
 */

const styleToc = css`
  top: 140px;
  right: 0;
  max-height: 100%;
  overflow: auto;

  ul {
    margin: 0 1rem;
    padding: 0;
    list-style: none;
  }

  nav > ul {
    margin: 0;
  }

  p {
    margin: 0;
    display: inline-block;
  }

  li {
    line-height: 1.4;
    margin-bottom: 0.5rem;
  }

  a {
    text-decoration: none;
    color: #777;

    &:hover {
      color: #779e01;
    }

    &:focus {
      text-decoration: underline;
    }
  }

  @media screen and (min-width: 60em) {
    & + article {
      margin-right: 16rem;
    }
  }
`

/**
 * Component
 */

const Toc = ({ toc }) => (
  <aside className="ml3 fixed w5 dn db-l" css={styleToc}>
    <h4 className="ttu mt0 mb3">Table Of Contents</h4>
    <nav dangerouslySetInnerHTML={{ __html: toc }} />
  </aside>
)

Toc.propTypes = {
  toc: PropTypes.string.isRequired
}

export default Toc
