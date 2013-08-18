tell
====

Promise-based Node.js Web framework

    tell = require 'tell'
    
    ...
    withTransaction = (handler) ->
     (req, res, next) ->
        db.begin()
          .then(-> handler(req, res, next))
          .then(db.commit)
          .fail(db.rollback)
    ...
    
    ...
    authenticatedOnly = (handler) ->
      (req, res, next) ->
        if not req.user?
          next()
        else
          handler(req, res, next)
    ...
    
    app = tell.stack()
      .use withTransaction myHandler
      .use authenticatedOnly anotherHandler
      .catch (err, req, res, next) ->
        console.log 'error: ', err
        next(err)
        
    app.listen(3000)
