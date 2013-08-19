###

  tell

  2013 (c) Andrey Popp <8mayday@gmail.com>

###

http              = require 'http'
{resolve, reject} = require 'kew'

createServer = (handler) ->
  http.createServer (req, res) ->
    handler(null, req, res, resolve)
      .then -> res.end()
      .end()

asPromise = (func, args...) ->
  try
    resolve func(args...)
  catch err
    reject err

toHandler = (h) ->
  if h.toHandler? then h.toHandler() else h

makeURIPrefixRe = (pattern) ->
  if pattern
    pattern = "/#{pattern}" unless pattern[0] == '/'
    ///^#{pattern}(/|$)///

makeURIRe = (pattern) ->
  if pattern
    pattern = "/#{pattern}" unless pattern[0] == '/'
    ///^#{pattern}$///

overlay = (obj, attrs) ->
  newObj = Object.create(obj)
  for k, v of attrs
    newObj[k] = v
  newObj

class Tell

  constructor: (handlers = []) ->
    this.handlers = handlers

  use: (prefix, handler) ->
    unless handler?
      handler = prefix
      prefix = undefined
    this.handlers.push
      pattern: makeURIPrefixRe prefix
      onSuccess: toHandler handler
    this

  catch: (handler) ->
    this.handlers.push
      onError: toHandler handler
    this

  for method in ['GET', 'HEAD', 'POST', 'PUT', 'DELETE',
                 'PATCH', 'OPTIONS', 'LINK', 'UNLINK']
    do (method) =>
      this.prototype[method.toLowerCase()] = (pattern, handler) ->
        pattern = makeURIRe pattern unless pattern instanceof RegExp
        this.handlers.push
          pattern: pattern
          method: method
          onSuccess: handler
          originalReq: true
        this

  listen: (args...) ->
    createServer(this.toHandler()).listen(args...)

  toHandler: ->
    this.handle.bind(this)

  matchTarget: (target, req, options) ->
    if options.pattern
      m = options.pattern.exec req.url
      return unless m
      unless options.originalReq
        newUrl = req.url.substring(m[0].length)
        newUrl = "/#{newUrl}" unless newUrl[0] == '/'
        req = overlay req, url: newUrl

    if options.method
      return unless req.method == options.method

    {target, localReq: req}

  handle: (err, req, res, next) ->
    handlers = this.handlers.slice(0)

    findHandler = (name, req) =>
      while handlers.length > 0
        handler = handlers.shift()
        target = handler[name]
        return unless target
        match = this.matchTarget(target, req, handler)
        return match if match?

    process = (err, result) =>
      nextIsCalled = false

      callNext = (err, result) =>
        nextIsCalled = true
        process(err, result)

      handlerName = if err then 'onError' else 'onSuccess'
      handler = findHandler(handlerName, req)

      unless handler
        if next?
          asPromise(next, err, result)
        else
          if err then reject(err) else resolve(result)


      else
        {target, localReq} = handler

        handled = if target.length == 4
          asPromise(target, err, localReq, res, callNext)
        else 
          asPromise(target, localReq, res, callNext)

        handled
          .then (result) =>
            if nextIsCalled then result else callNext(null, result)
          .fail (err) =>
            if nextIsCalled then throw err else callNext(err)

    process(err)

module.exports = -> new Tell

for k, v of {createServer, Tell}
  module.exports[k] = v
