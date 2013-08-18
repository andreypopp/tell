###

  tell specs

  2013 (c) Andrey Popp <8mayday@gmail.com>

###

{resolve, reject}                     = require 'kew'
{ok, throws: throwsFlip, equal: eq}   = require 'assert'
tell                                  = require './index'

throws = (error, block) ->
  throwsFlip block, error

describe 'Stack', ->

  it 'works as a middleware stack', (done) ->
    trace = []
    app = tell.stack()
      .use (req, res, next) ->
        eq req, 1
        eq res, 2
        trace.push 0
        next()
      .use (req, res, next) ->
        eq req, 1
        eq res, 2
        trace.push 1
        'ok'
    app.handle(null, 1, 2)
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 2
        eq trace[0], 0
        eq trace[1], 1
      .then(done)
      .end()

  it 'automatically calls next handler if no explicit call was made', (done) ->
    trace = []
    app = tell.stack()
      .use (req, res, next) ->
        eq req, 1
        eq res, 2
        trace.push 0
      .use (req, res, next) ->
        eq req, 1
        eq res, 2
        trace.push 1
        'ok'
    app.handle(null, 1, 2)
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 2
        eq trace[0], 0
        eq trace[1], 1
      .then(done)
      .end()

  it 'handles empty stack', (done) ->
    app = tell.stack()
    app.handle(null)
      .then (res) ->
        eq res, undefined
      .then(done)
      .end()

  it 'allows delegating to sub-stacks', (done) ->
    trace = []
    app = tell.stack()
      .use (req, res, next) ->
        eq req, 1
        eq res, 2
        trace.push 0
      .use tell.stack()
        .use (req, res, next) ->
          eq req, 1
          eq res, 2
          trace.push 1
        .use (req, res, next) ->
          eq req, 1
          eq res, 2
          trace.push 2
          'ok'
    app.handle(null, 1, 2)
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 3
        eq trace[0], 0
        eq trace[1], 1
        eq trace[2], 2
      .then(done)
      .end()

  it 'propagates thrown error to top level', ->
    app = tell.stack()
      .use (req, res, next) -> 
        throw new Error('error')
    throws Error, ->
      app.handle(null)
        .fail (err) ->
          ok err
          throw err
        .end()

  it 'propagates rejected promise to top level', ->
    app = tell.stack()
      .use (req, res, next) ->
        reject new Error('error')
    throws Error, ->
      app.handle(null)
        .fail (err) ->
          ok err
          throw err
        .end()

  it 'catches thrown error with a handler', (done) ->
    trace = []
    app = tell.stack()
      .use (req, res, next) ->
        throw new Error('error')
      .catch (err, req, res, next) ->
        eq req, 1
        eq res, 2
        ok err
        trace.push 1
      .use (req, res, next) ->
        eq req, 1
        eq res, 2
        trace.push 2
        'ok'
    app.handle(null, 1, 2)
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 2
      .then(done)
      .end()

  it 'catches rejected error with a handler', (done) ->
    trace = []
    app = tell.stack()
      .use (req, res, next) ->
        reject new Error('error')
      .catch (err, req, res, next) ->
        eq req, 1
        eq res, 2
        ok err
        trace.push 1
      .use (req, res, next) ->
        eq req, 1
        eq res, 2
        trace.push 2
        'ok'
    app.handle(null, 1, 2)
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 2
      .then(done)
      .end()

  it 'propagates re-thrown error', ->
    trace = []
    app = tell.stack()
      .use (req, res, next) ->
        throw new Error('error')
      .catch (err, req, res, next) ->
        ok err
        trace.push 1
        throw err
    throws Error, ->
      app.handle(null, 1, 2)
        .fail (err) ->
          ok err
          eq trace.length, 1
          throw err
        .end()

  it 'propagates re-rejected error', ->
    trace = []
    app = tell.stack()
      .use (req, res, next) ->
        reject new Error('error')
      .catch (err, req, res, next) ->
        ok err
        trace.push 1
        reject(err)
    throws Error, ->
      app.handle(null)
        .fail (err) ->
          ok err
          eq trace.length, 1
          throw err
        .end()