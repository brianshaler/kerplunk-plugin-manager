_ = require 'lodash'

module.exports = (plugins) ->
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
