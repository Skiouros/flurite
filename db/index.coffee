fs = require "fs"
path = require "path"

query = require "pg-query"
clc = require "cli-color"

sql = clc.cyanBright
magenta = clc.redBright

class Database
    instance = null

    TRUE: "TRUE"
    FALSE: "FALSE"
    NULL: "NULL"

    @get: ->
        instance ?= new Database()

    escape_var: (obj) ->
        if obj == @NULL then return @NULL

        switch typeof obj
            when "string" then "'#{obj.split("'").join "''"}'"
            when "boolean" then (if obj then @TRUE else @FALSE)
            else obj

    escape_name: (obj) ->
        "\"#{obj}\""

    query: (text, values, cb) ->
        console.log "#{sql "SQL"}: #{magenta text}"
        try
            query(text, values, cb)
        catch error
            console.log error


    select: (text, values, cb) ->
        @query "SELECT #{text}", values, cb

    insert: (table, info, ret) ->
        ret = [ret] if "string" == typeof ret
        values = []

        for k, v of info
            values.push v

        q = "INSERT INTO #{@escape_name table} (#{Object.keys(info).join ","}) VALUES (#{("$#{i}" for i in [1..values.length] by 1).join ","})"
        q= "#{q} RETURNING #{ret.join ","}" if ret

        @query q, values

    update: (table, values, conditions) ->
        value = ("#{@escape_name k} = #{@escape_var v}" for k, v of values)
        condition = ("#{@escape_name k} = #{@escape_var v}" for k, v of conditions)

        q = "UPDATE #{@escape_name table} SET #{value.join ", "} WHERE #{condition.join " and "}"
        @query q

    delete: (table, conditions) ->
        condition = ("#{@escape_name k} = #{@escape_var v}" for k, v of conditions)
        @query "DELETE FROM #{@escape_name table} WHERE #{condition.join " and "}"

    setup: (conn_str, app) ->
        query.connectionParameters = conn_str

        @schema = require "./schema"
        @Model = require "./model"
        # @load_models()
        @

    load_models: ->
        @models = {}
        fs
            .readdirSync("models/")
            .filter (file) => path.extname(file) == ".js"
            .forEach (file) =>
                console.log file
                model = require("models/#{file}")
                @models[model.name] = model

            for name, model of @models
                model.associate @models if model.associate


module.exports = Database.get()
