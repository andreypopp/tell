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

stack = ->
  new Stack

module.exports = {createServer, Stack, stack}