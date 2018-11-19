import * as React from 'react'
import PropTypes from 'prop-types'
import { Link } from 'gatsby'
import { compose, join, juxt, toUpper, head, tail, isNil, unless } from 'ramda'

const capitalize = compose(
  join(''),
  juxt([
    compose(
      toUpper,
      head
    ),
    tail
  ])
)

const capitalizeIfNotNil = unless(isNil, capitalize)

const Sidebar = ({ nav }) => (
  <aside>
    <nav>
      <ul className="list ma0 pl0">
        {nav.map((item, index) => (
          <li key={index}>
            <h3>{capitalizeIfNotNil(item.section)}</h3>
            <ul>
              {item.edges.map(edge => (
                <li key={edge.node.id}>
                  <Link
                    to={edge.node.fields.slug}
                    activeClassName="green"
                    className="link gray db mv1"
                  >
                    {edge.node.frontmatter.title}
                  </Link>
                </li>
              ))}
            </ul>
          </li>
        ))}
      </ul>
    </nav>
  </aside>
)

Sidebar.propTypes = {
  nav: PropTypes.array.isRequired
}

export default Sidebar
