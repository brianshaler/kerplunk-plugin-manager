_ = require 'lodash'
React = require 'react'

{DOM} = React

module.exports = React.createFactory React.createClass
  render: ->
    DOM.div null,
      DOM.h4 null, 'Recommended plugins:'
      _.map @props.recommended, (rec) =>
        id = "#{@props.keyPrefix}-rec-#{rec}"
        DOM.div
          key: id
        ,
          DOM.input
            type: 'checkbox'
            id: id
            onChange: @props.toggleRecommendation rec
            checked: !!(_.find @props.selected, (r) -> r == rec)
          ' '
          DOM.label
            htmlFor: id
          , rec
