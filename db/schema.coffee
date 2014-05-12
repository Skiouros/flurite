db = require "../db"

exists = (name) ->
    db.select "COUNT(*) as c FROM pg_class WHERE relname = #{db.escape_var name}"
        .then (r) ->
            return r.rows[0].c > 0

gen_index_name = (name, col) ->
    "#{name}_#{col}_idx"

extract_options = (options...) ->
    columns = []
    values = {}

    for k in options[0]
        if "object" == typeof k
            values = k
        else
            columns.push k

    return columns: columns, options: values

create_table = (name, columns) ->
    q = "CREATE TABLE IF NOT EXISTS #{db.escape_name name} ("

    buffer = []
    for c in columns
        if "string" == typeof c
            buffer.push c
        else
            buffer.push "#{db.escape_name c.name} #{c.type}"

    db.query "#{q}\n  #{buffer.join ",\n  "}\n)"

add_column = (name, col_name, col_type) ->
    name = db.escape_name name
    col_name = db.escape_name col_name
    db.query "ALTER TABLE #{name} ADD COLUMN #{col_name} #{col_type}"

drop_index = (name, index) ->
    exists index_name
        .then (exists) ->
            return if exists
            db.query "DROP INDEX IF EXISTS #{db.escape_name "#{name}_#{index}_idx"}"

drop_table = (name) ->
    db.query "DROP TABLE IF EXISTS #{db.escape_name name}"

drop_column = (name, col_name) ->
    name = db.escape_name name
    col_name = db.escape_name col_name
    db.query "ALTER TABLE #{name} DROP COLUMN #{col_name}"

create_index = (name, options...) ->
    res = extract_options options
    index_name = "#{name}_#{res.columns.join ""}_idx"

    exists index_name
        .then (exists) ->
            return if exists

            q = ["CREATE"]
            q.push " UNIQUE" if res.options.unique
            q.push " INDEX ON #{db.escape_name name} ("
            q.push "#{res.columns.join ", "})"
            q.push ";"

            db.query q.join ""

rename_table = (name_from, name_to) ->
    name_from = db.escape_name name_from
    name_to = db.escape_name name_to
    db.query "ALTER TABLE #{name_from} RENAME TO #{name_to}"

rename_column = (name, col_from, col_to) ->
    name = db.escape_name name
    col_from = db.escape_name col_from
    col_to = db.escape_name col_to
    db.query "ALTER #{name} RENAME COLUMN #{col_from} TO #{col_to}"

class ColumnType

    constructor: (@base, @default_opts) ->
        @default_opts ?= {}

    c: (opts) ->
        out = @base

        for k, v of @default_opts
            opts[k] = v if opts[k] == null

        if opts.default?
            out = "#{out} DEFAULT #{db.escape_var opts.default}"

        if opts.null?
            out = "#{out} NOT NULL"

        if opts.primary_key?
            out = "#{out} PRIMARY KEY"

        out

    toString: ->
        @c @default_opts

C = (base, options) ->
    new ColumnType(base, options)

types =
    serial: C "serial", null: false
    varchar: C "character varying(255)", null: false
    text: C "text", null: false
    time: C "timestamp", null: false
    date: C "date", null: false
    integer: C "integer", null: false, default: 0
    numeric: C "numeric", null: false, default: 0
    real: C "real", null: false, default: 0
    double: C "double percision", null: false, default: 0
    boolean: C "boolean", null: false, default: false
    timestamp: C "timestamp without time zone", null: false
    foreign_key: C "integer", null: false

module.exports =
    add_column: add_column
    create_table: create_table
    create_index: create_index
    drop_index: drop_index
    drop_table: drop_table
    drop_column: drop_column
    rename_table: rename_table
    rename_colum: rename_column
    exists: exists
    types: types
