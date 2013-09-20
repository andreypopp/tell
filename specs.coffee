###

  tell specs

  2013 (c) Andrey Popp <8mayday@gmail.com>

###

{resolve, reject}                     = require 'kew'
{ok, throws: throwsFlip, equal: eq}   = require 'assert'
tell                                  = require './index'

throws = (error, block) ->
  throwsFlip block, error

describe 'Tell', ->

  it 'works as a middleware tell', (done) ->
    trace = []
    app = tell()
      .use (req, res, next) ->
        ok req.req
        ok res.res
        trace.push 0
        next()
      .use (req, res, next) ->
        ok req.req
        ok res.res
        trace.push 1
        'ok'
    app.handle(null, {req: true}, {res: true})
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 2
        eq trace[0], 0
        eq trace[1], 1
      .then(done)
      .end()

  it 'automatically calls next handler if no explicit call was made', (done) ->
    trace = []
    app = tell()
      .use (req, res, next) ->
        ok req.req
        ok res.res
        trace.push 0
      .use (req, res, next) ->
        ok req.req
        ok res.res
        trace.push 1
        'ok'
    app.handle(null, {req: true}, {res: true})
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 2
        eq trace[0], 0
        eq trace[1], 1
      .then(done)
      .end()

  it 'handles empty tell', (done) ->
    app = tell()
    app.handle(null, {req: true}, {res: true})
      .then (res) ->
        eq res, undefined
      .then(done)
      .end()

  it 'allows delegating to sub-tells', (done) ->
    trace = []
    app = tell()
      .use (req, res, next) ->
        ok req.req
        ok res.res
        trace.push 0
      .use tell()
        .use (req, res, next) ->
          ok req.req
          ok res.res
          trace.push 1
        .use (req, res, next) ->
          ok req.req
          ok res.res
          trace.push 2
          'ok'
    app.handle(null, {req: true}, {res: true})
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 3
        eq trace[0], 0
        eq trace[1], 1
        eq trace[2], 2
      .then(done)
      .end()

  it 'propagates thrown error to top level', ->
    app = tell()
      .use (req, res, next) -> 
        throw new Error('error')
    throws Error, ->
      app.handle(null, {req: true}, {res: true})
        .fail (err) ->
          ok err
          throw err
        .end()

  it 'propagates rejected promise to top level', ->
    app = tell()
      .use (req, res, next) ->
        reject new Error('error')
    throws Error, ->
      app.handle(null, {req: true}, {res: true})
        .fail (err) ->
          ok err
          throw err
        .end()

  it 'propagates passed error to top level', ->
    app = tell()
      .use (req, res, next) ->
        next new Error('error')
    throws Error, ->
      app.handle(null, {req: true}, {res: true})
        .fail (err) ->
          ok err
          throw err
        .end()

  it 'catches thrown error with a handler', (done) ->
    trace = []
    app = tell()
      .use (req, res, next) ->
        throw new Error('error')
      .catch (err, req, res, next) ->
        ok req.req
        ok res.res
        ok err
        trace.push 1
      .use (req, res, next) ->
        ok req.req
        ok res.res
        trace.push 2
        'ok'
    app.handle(null, {req: true}, {res: true})
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 2
      .then(done)
      .end()

  it 'catches rejected promise with a handler', (done) ->
    trace = []
    app = tell()
      .use (req, res, next) ->
        reject new Error('error')
      .catch (err, req, res, next) ->
        ok req.req
        ok res.res
        ok err
        trace.push 1
      .use (req, res, next) ->
        ok req.req
        ok res.res
        trace.push 2
        'ok'
    app.handle(null, {req: true}, {res: true})
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 2
      .then(done)
      .end()

  it 'catches passed error with a handler', (done) ->
    trace = []
    app = tell()
      .use (req, res, next) ->
        next new Error('error')
      .catch (err, req, res, next) ->
        ok req.req
        ok res.res
        ok err
        trace.push 1
      .use (req, res, next) ->
        ok req.req
        ok res.res
        trace.push 2
        'ok'
    app.handle(null, {req: true}, {res: true})
      .then (res) ->
        eq res, 'ok'
        eq trace.length, 2
      .then(done)
      .end()

  it 'propagates re-thrown error', ->
    trace = []
    app = tell()
      .use (req, res, next) ->
        throw new Error('error')
      .catch (err, req, res, next) ->
        ok err
        trace.push 1
        throw err
    throws Error, ->
      app.handle(null, {req: true}, {res: true})
        .fail (err) ->
          ok err
          eq trace.length, 1
          throw err
        .end()

  it 'propagates re-rejected promise', ->
    trace = []
    app = tell()
      .use (req, res, next) ->
        reject new Error('error')
      .catch (err, req, res, next) ->
        ok err
        trace.push 1
        reject err
    throws Error, ->
      app.handle(null, {req: true}, {res: true})
        .fail (err) ->
          ok err
          eq trace.length, 1
          throw err
        .end()

  it 'propagates re-passed error', ->
    trace = []
    app = tell()
      .use (req, res, next) ->
        next new Error('error')
      .catch (err, req, res, next) ->
        ok err
        trace.push 1
        next err
    throws Error, ->
      app.handle(null, {req: true}, {res: true})
        .fail (err) ->
          ok err
          eq trace.length, 1
          throw err
        .end()

  describe 'mounting a handler under a pattern', ->

    it 'responds to exact match', (done) ->
      trace = []
      app = tell()
        .use '/a', (req, res) ->
          eq req.url, '/'
          trace.push 1
        .use '/b', (req, res) ->
          trace.push 2
        .use (req, res) ->
          eq req.url, '/a'
          trace.push 3

      app.handle(null, {url: '/a'}, {res: true})
        .then (res) ->
          eq trace.length, 2
          eq trace[0], 1
          eq trace[1], 3
        .then(done)
        .end()

    it 'responds to match of a leading part', (done) ->
      trace = []
      app = tell()
        .use '/a', (req, res) ->
          eq req.url, '/b'
          trace.push 1
        .use '/b', (req, res) ->
          trace.push 2
        .use (req, res) ->
          eq req.url, '/a/b'
          trace.push 3

      app.handle(null, {url: '/a/b'}, {res: true})
        .then (res) ->
          eq trace.length, 2
          eq trace[0], 1
          eq trace[1], 3
        .then(done)
        .end()

    it 'does not respond to arbitrary match of a leading part', (done) ->
      trace = []
      app = tell()
        .use '/a', (req, res) ->
          trace.push 1
        .use '/b', (req, res) ->
          trace.push 2
        .use (req, res) ->
          trace.push 3

      app.handle(null, {url: '/ab'}, {res: true})
        .then (res) ->
          eq trace.length, 1
          eq trace[0], 3
        .then(done)
        .end()

    it 'does not respond to a no match case', (done) ->
      trace = []
      app = tell()
        .use '/a', (req, res) ->
          trace.push 1
        .use '/b', (req, res) ->
          trace.push 2
        .use (req, res) ->
          trace.push 3

      app.handle(null, {url: '/c'}, {res: true})
        .then (res) ->
          eq trace.length, 1
          eq trace[0], 3
        .then(done)
        .end()

  describe 'routing to endpoints', ->

    it 'routes by method and URI pattern', (done) ->
      trace = []
      app = tell()
        .get '/info', (req, res) ->
          trace.push 1
        .post '/info', (req, res) ->
          trace.push 2
      app.handle(null, {url: '/info', method: 'POST'}, {res: true})
        .then (res) ->
          eq trace.length, 1
          eq trace[0], 2
        .then(done)
        .end()
