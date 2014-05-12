_ = require "underscore"

bind = (method, context) ->
    ->
        method.apply(context, arguments)

verbs = {"get", "post", "delete", "put"}
class Application
    routes: {}

    constructor: (@app) ->

    handle_req: (req, res, args) ->
        args.values.url_for = @url_for
        args.values.static = @app.get "static"

        if args.redirect?
            res.redirect args.redirect
        else if args.layout? and !args.json
            res.render args.layout, args.values
        else if args.json
            res.send JSON.stringify args.json

    include: (klass) ->
        obj = new klass()
        routes = (k for k of obj when k not in ["path", "name"])
        paths = []

        for route in routes
            # unnamed route
            fn = null
            if typeof obj[route] == "function"
                options = obj[route]()
                throw "Route: #{route} must have action" if not options?

                options.name = route
                paths.push path: route, options: options
                continue

            # named route
            for path, fn of obj[route]
                options = fn()
                options.name = route
                paths.push path: path, options: options


        for p in paths
            p.options.name = "#{klass.route_name}#{p.options.name}" if klass.route_name
            p.options.before = klass.before if klass.before?

            if klass.path
                p.path = "#{klass.path}#{p.path}" if klass.path
                p.path = p.path.slice(0, -1) if p.path.slice(-1) == "/"

            @route p.path, p.options


    route: (path, options) ->
        # path = "#{path}#{options.path}" if options.path?
        @routes[options.name] = path if options.name?

        for verb of verbs
            cb = (req, res, next) =>

                params = _.extend {}, req.body, req.query, req.params
                req_obj = req: req, res: res, params: params, next: next, url_for: @url_for
                req_obj.done = (args) =>
                        args.values ?= {}
                        console.log args
                        @handle_req req, res, args

                cb_chain = =>
                    method = options[req.method.toLowerCase()]

                    while typeof method == "function"
                        method = bind(method, req_obj)
                        method = method() if method?

                    if method?
                        method.values ?= {}
                        @handle_req req, res, method

                before = bind(options.before, req_obj) if options.before?
                if before
                    before(cb_chain) if before?
                else
                    cb_chain()

            @app[verb](path, cb) if options[verb]?

    url_for: (name) =>
        @routes[name]

module.exports = Application
