_ = require 'lodash'
React = require 'react'
Bootstrap = require 'react-bootstrap'

Category = require './category'
Search = require './search'
categorize = require './categorize'

{DOM} = React

Accordion = React.createFactory Bootstrap.Accordion
Panel = React.createFactory Bootstrap.Panel

module.exports = React.createFactory React.createClass
  getInitialState: ->
    plugins: @props.plugins ? []
    permissions: @props.permissions ? {}
    categorizedPlugins: @categorizePlugins @props.plugins ? []
    recommendations: []
    showRecommendations: false

  togglePlugin: (plugin, permissions = [], additional = []) ->
    if plugin.kerplunk?.dependencies
      console.log 'add deps', plugin.kerplunk.dependencies
      additional = _.unique additional.concat plugin.kerplunk.dependencies
    console.log 'toggle plugin', plugin, additional
    action = if plugin.enabled then 'disable' else 'enable'
    url = "/admin/plugins/#{plugin.name}/#{action}.json"
    console.log url
    data =
      permissions: permissions.join ','
      additional: additional.join ','

    @props.request.post url, data, (err, obj) =>
      console.log 'response', err, obj
      return console.log err if err
      return unless @isMounted()
      newPlugins = obj?.plugins ? @state.plugins
      @setState
        plugins: newPlugins
        permissions: obj.permissions ? @state.permissions
        categorizedPlugins: @categorizePlugins newPlugins
      @props.refreshState()

  # componentWillReceiveProps: (newProps) ->
  #   console.log 'receiving props', newProps?.plugins?
  #   if newProps.plugins and newProps.plugins != @state.plugins
  #     @setState
  #       categorizedPlugins: @categorizePlugins newProps.plugins
  #   @setState
  #     plugins: newProps.plugins ? @state.plugins
  #     permissions: newProps.permissions ? @state.permissions

  categorizePlugins: (plugins = @state.plugins) ->
    all =
      active: {}
      available: {}
    all = _ plugins
      .filter (plugin) -> !plugin.isCore
      .reduce (memo, plugin) ->
        bucket = if plugin.enabled
          memo.active
        else
          memo.available
        categories = _ plugin.keywords
          .filter (keyword) -> /^kp:/.test keyword
          .map (keyword) -> keyword.substring 3
          .value()
        unless categories.length > 0
          categories.push 'Miscellaneous'
        for category in categories
          bucket[category] = [] unless bucket[category]
          bucket[category].push plugin
        memo
      , {active: {}, available: {}}
    all.active = _ all.active
      .map (plugins, name) ->
        name: name
        plugins: _.sortBy plugins, (plugin) ->
          plugin.displayName ? plugin.name
      .sortBy 'name'
      .value()
    all.available = _ all.available
      .map (plugins, name) ->
        name: name
        plugins: _.sortBy plugins, (plugin) ->
          plugin.displayName ? plugin.name
      .sortBy 'name'
      .value()
    # console.log 'all', all
    all

  getRecommendations: (e) ->
    e.preventDefault()
    @setState
      showRecommendations: true
      recommendations: 'loading'
    url = '/admin/plugins/recommended.json'
    @props.request.get url, {}, (err, data) =>
      if err
        @setState
          showRecommendations: true
          recommendations: 'error'
        return console.log err
      if data?.plugins?.length > 0
        console.log "got #{data.plugins.length} plugins, filtering out #{@state.plugins.length} existing"
        newPlugins = _ data.plugins
        .map (plugin) ->
          try
            obj = JSON.parse plugin.data
            if obj?.versions?[obj?['dist-tags']?.latest]
              _.merge plugin, obj.versions[obj['dist-tags'].latest]
          catch ex
            console.log "could not parse plugin.data for #{plugin?.name}"
          plugin
        .filter (plugin) =>
          !(_.find @state.plugins, (p) => p.name == plugin.name)
        .value()
        console.log 'new', newPlugins, @state.plugins[0]
        @setState
          recommendations: categorize newPlugins

  render: ->
    {active, available} = @state.categorizedPlugins

    DOM.section
      className: 'content'
    ,
      DOM.div
        className: 'row'
      ,
        DOM.div
          className: 'col col-lg-12'
        , Search _.extend {}, @props, @state,
          togglePlugin: @togglePlugin
      DOM.div
        className: 'row'
      ,
        DOM.div
          className: 'plugin-list col-md-6'
        ,
          DOM.h3 null,
            'Active Plugins ('
            _.filter(@state.plugins, (p) -> p.enabled and !p.isCore).length
            ')'
          Accordion
            className: ''
            eventKey: '1'
          , _.map active, (category, index) =>
              Category _.extend {}, @props, @state,
                key: "category-#{category.name}"
                eventKey: String index
                category: category.name
                plugins: category.plugins
                allPlugins: @state.plugins
                togglePlugin: @togglePlugin
        DOM.div
          className: 'plugin-list col-md-6'
        ,
          DOM.h3 null,
            'Available Plugins ('
            _.filter(@state.plugins, (p) -> !p.enabled and !p.isCore).length
            ')'
          Accordion
            className: 'plugin-list'
          , _.map available, (category, index) =>
              Category _.extend {}, @props, @state,
                key: "category-#{category.name}"
                eventKey: String index
                category: category.name
                plugins: category.plugins
                allPlugins: @state.plugins
                togglePlugin: @togglePlugin
          DOM.h3 null, 'Recommended Plugins'
          if @state.showRecommendations
            if @state.recommendations == 'loading'
              DOM.div null, 'loading'
            else if @state.recommendations == 'error'
              DOM.div null, 'error'
            else if @state.recommendations instanceof Array
              if @state.recommendations.length == 0
                DOM.div null, 'no recommendations at this time'
              else
                Accordion
                  className: 'plugin-list'
                , _.map @state.recommendations, (category, index) =>
                    Category _.extend {}, @props, @state,
                      key: "category-#{category.name}"
                      eventKey: String index
                      category: category.name
                      plugins: category.plugins
                      allPlugins: @state.plugins
                      togglePlugin: @togglePlugin
          else
            DOM.a
              href: '#'
              onClick: @getRecommendations
              className: 'btn btn-default'
            , 'find recommended plugins'
        DOM.div
          style:
            clear: 'both'
