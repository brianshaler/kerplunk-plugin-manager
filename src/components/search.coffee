_ = require 'lodash'
React = require 'react'
Bootstrap = require 'react-bootstrap'

Accordion = React.createFactory Bootstrap.Accordion
Button = React.createFactory Bootstrap.Button
Input = React.createFactory Bootstrap.Input

Category = require './category'

{DOM} = React

module.exports = React.createFactory React.createClass
  getInitialState: ->
    expanded: false
    results: []
    loading: false

  onSubmit: (e) ->
    e.preventDefault()
    console.log 'search!', @refs.search.getValue()
    url = '/admin/plugins/search.json'
    opt =
      q: @refs.search.getValue()
    @props.request.get url, opt, (err, data) =>
      return unless @isMounted()
      for plugin in data.plugins
        if plugin.data
          try
            obj = JSON.parse plugin.data
            if obj?.versions?[obj?['dist-tags']?.latest]
              _.merge plugin, obj.versions[obj['dist-tags'].latest]
          catch ex
            console.log "could not parse plugin.data for #{plugin?.name}"
      console.log 'data', data
      results = _.map data.plugins, (plugin) =>
        latest = _.find @props.plugins, (p) ->
          p.name == plugin.name
        plugin = _.merge {}, plugin, latest if latest
        plugin
      @setState
        loading: false
        results: results
        resultsByCategory: @resultsByCategory results
    @setState
      results: []
      loading: true
      expanded: true

  componentWillReceiveProps: (newProps) ->
    # console.log 'search props', @state.results?.length > 0, newProps.plugins?
    if @state.results?.length > 0 and newProps.plugins
      results = _.map @state.results, (result) ->
        latest = _.find newProps.plugins, (plugin) ->
          result.name == plugin.name
        result = latest if latest
        result
      @setState
        results: results
        resultsByCategory: @resultsByCategory results

  resultsByCategory: (plugins) ->
    grouped = _ plugins
      .reduce (memo, plugin) ->
        categories = _ plugin.keywords
          .filter (keyword) -> /^kp:/.test keyword
          .map (keyword) -> keyword.substring 3
          .value()
        unless categories.length > 0
          categories.push 'Miscellaneous'
        for category in categories
          memo[category] = [] unless memo[category]
          memo[category].push plugin
        memo
      , {}
    _ grouped
      .map (plugins, name) ->
        name: name
        plugins: _.sortBy plugins, (plugin) ->
          plugin.displayName ? plugin.name
      .sortBy 'name'
      .value()

  render: ->
    searchButton = Button
      onClick: @onSubmit
    , 'Search'

    DOM.div
      className: 'plugin-search'
    ,
      DOM.form
        onSubmit: @onSubmit
      ,
        Input
          type: 'text'
          ref: 'search'
          placeholder: 'search for tag or keyword here..'
          buttonAfter: searchButton
      if @state.expanded
        if @state.loading
          DOM.h3 null, 'Loading...'
        else
          if @state.results.length == 0
            DOM.div null, 'no results'
          else
            Accordion
              className: 'plugin-list'
            ,
              _.map @state.resultsByCategory, (category, index) =>
                Category _.extend {}, @props,
                  key: "search-category-#{category.name}"
                  eventKey: String index
                  category: category.name
                  plugins: category.plugins
                  allPlugins: @props.plugins
