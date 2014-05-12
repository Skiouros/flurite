# db = require "./db"
db = require "../db"
schema = db.schema
types = schema.types

get_timestamp = ->
    now = new Date()
    new Date(now.getTime() + (now.getTimezoneOffset()))

add_timestamp = (obj) ->
    ts = get_timestamp()
    obj.created_at = ts
    obj.updated_at = ts
    obj

class Model
    @table: ""
    @timestamp: false
    @primary_key: "id"

    constructor: ->
        @_primary_key = @constructor.primary_keys()
        @_table = @constructor.table
        @_timestamp = @constructor.timestamp

    @validate: (values) ->
        return true if not @constraints
        for key, value of values
            continue if not @constraints[key]

            result = @constraints[key](value)
            console.log result if result?
            return result if result != true
        true


    @primary_keys: ->
        if "string" == typeof @primary_key
            [@primary_key]
        else
            @primary_key

    @load_all: (rows) ->
        (@load row for i, row of rows)

    @load: (row) ->
        obj = new @()
        for k, v of row
            obj[k] = v
        obj

    @encode_key: (args...) ->
        args = args[0]
        ("#{db.escape_name @primary_keys()[i]} = #{db.escape_var args[i]}" for i in [0..args.length - 1]).join " and "

    @find: (args...) ->
        where = ""
        if Array.isArray args and "object" != typeof args[0]
            where = @encode_key args
        else
            where = ("#{db.escape_name k} = #{db.escape_var v}" for k, v of args[0]).join " and "

        r = db.select "* FROM #{db.escape_name @table} WHERE #{where} LIMIT 1"
        r.then (result) =>
            if result.rowCount > 0
                @load result.rows[0]

    @find_all: (keys, by_key=@primary_key) ->
        keys = (db.escape_var v for v in keys)
        r = db.select "* FROM #{db.escape_name @table} WHERE #{by_key} in (#{keys.join ", "})"

        r.then (result) =>
            if result.rowCount > 0
                @load_all result.rows

    @select: (conditions, fields) ->
        q = ["* FROM #{db.escape_name @table}"]
        if conditions
            condition = ("#{db.escape_name k} = #{db.escape_var v}" for k, v of conditions).join " and "
            q.push " WHERE #{condition}"
        r = db.select q.join ""

        r.then (result) =>
            if result.rowCount > 0
                @load_all result.rows

    @create: (info) ->
        info = add_timestamp info if @timestamp
        r = db.insert @table, info, @primary_keys()
        r.then (result) =>
            @load @find result.rows[0]

    delete: ->
        conditions = {}
        for k in @_primary_key
            conditions[k] = @[k]
        db.delete @_table, conditions

    update: (first, args...) ->
        conditions = {}
        values = {}

        for k in @_primary_key
            conditions[k] = @[k]

        if "string" == typeof first
            args.push first
            for k in args
                values[k] = @[k]
        else
            values = first

        values.updated_at = get_timestamp() if @_timestamp
        db.update @_table, values, conditions

    @has_many: (model) ->
        model_name = model.name.toLowerCase()
        model_id = "#{model_name}_id"

        this_name = @.name.toLowerCase()
        this_id = "#{this_name}_id"

        new_tbl = "#{this_name}_#{model_name}"
        primary_key = [this_id, model_id]

        schema.create_table new_tbl, [
            { name: "#{this_name}_id", type: types.foreign_key }
            { name: "#{model_name}_id", type: types.foreign_key }

            # OTHERS POSSIBLY
            "PRIMARY KEY (#{primary_key.join ", "})"
        ]

        new_model = db.models[new_tbl] = class extends Model
            @table: new_tbl
            @primary_key: primary_key

        @.prototype["has_#{model_name}"] = (info) ->
            # if info.__super__ is Model.prototype
            #     console.log "is a model!"
            model.find info
                .then (m) =>
                    return if not m
                    t = {}
                    t[model_id] = m.id
                    t[this_id] = @id
                    new_model.find t

        @.prototype["add_#{model_name}"] = (m) ->
            @["has_#{model_name}"](m)
                .done (r) =>
                    return if r

                    model.find m
                        .then (m) =>
                            return if not m
                            t = {}
                            t[model_id] = m.id
                            t[this_id] = @id
                            new_model.create t

        @.prototype["remove_#{model_name}"] = (m) ->
            @["has_#{model_name}"](m)
                .done (r) =>
                    return if not r

                    model.find m
                        .then (m) =>
                            t = {}
                            t[model_id] = m.id
                            t[this_id] = @id
                            new_model.find t
                                .then (other) ->
                                    other.delete()

module.exports = Model
