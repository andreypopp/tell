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

makeURIPartRe = (pattern) ->
  pattern = "/#{pattern}" unless pattern[0] == '/'
  ///^#{pattern}(/|$)///

makeURIRe = (pattern) ->
  pattern = "/#{pattern}" unless pattern[0] == '/'
  ///^#{pattern}$///

overlay = (obj, attrs) ->
  newObj = Object.create(obj)
  for k, v of attrs
    newObj[k] = v
  newObj

class Stack

  constructor: (handlers = []) ->
    this.handlers = handlers

  use: (handler) ->
    this.handlers.push {onSuccess: toHandler handler}
    this

  catch: (handler) ->
    this.handlers.push {onError: toHandler handler}
    this

  listen: (args...) ->
    createServer(this.toHandler()).listen(args...)

  toHandler: ->
    this.handle.bind(this)

  handle: (err, req, res, next) ->
    handlers = this.handlers.slice(0)

    nextHandler = (name) ->
      while handlers.length > 0
        handler = handlers.shift()
        return handler[name] if handler[name]

    process = (err, result) ->
      nextIsCalled = false

      callNext = (err, result) ->
        nextIsCalled = true
        process(err, result)

      handler = nextHandler(if err then 'onError' else 'onSuccess')

      unless handler
        if next?
          asPromise(next, err, result)
        else
          if err then reject(err) else resolve(result)

      else
        handled = if handler.length == 4
          asPromise(handler, err, req, res, callNext)
        else 
          asPromise(handler, req, res, callNext)

        handled
          .then (result) ->
            if nextIsCalled then result else callNext(null, result)
          .fail (err) ->
            if nextIsCalled then throw err else callNext(err)

    process(err)

class Router extends Stack

  use: (pattern, handler, _mangle = true) ->
    if handler
      pattern = makeURIPartRe pattern unless pattern instanceof RegExp
      wrapperHandler = (req, res, next) ->
        m = pattern.exec req.url
        if m
          if _mangle
            newUrl = req.url.substring(m[0].length)
            newUrl = "/#{newUrl}" unless newUrl[0] == '/'
            req = overlay req, url: newUrl
          handler(req, res, next)
        else
          next()
      super wrapperHandler
    else
      handler = pattern
      super handler

  for method in ['GET', 'HEAD', 'POST', 'PUT', 'DELETE',
                 'PATCH', 'OPTIONS', 'LINK', 'UNLINK']
    do (method) =>
      this.prototype[method.toLowerCase()] = (pattern, handler) ->
        pattern = makeURIRe pattern unless pattern instanceof RegExp
        wrapperHandler = (req, res, next) ->
          if req.method == method
            handler(req, res, next)
          else
            next()
        this.use pattern, wrapperHandler, false

stack = -> new Stack
router = -> new Router


module.exports = {createServer, Stack, stack, Router, router}
