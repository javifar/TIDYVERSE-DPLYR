#' @include translate-sql-helpers.r
#' @include sql-escape.r
NULL

base_scalar <- sql_translator(
  `==`    = sql_infix("="),
  `!`     = sql_prefix("not"),
  `&`     = sql_infix("and"),
  `&&`    = sql_infix("and"),
  `|`     = sql_infix("or"),
  `||`    = sql_infix("or"),
  `^`     = sql_prefix("power"),
  `%%`    = sql_infix("%"),
  ceiling = sql_prefix("ceil"),
  tolower = sql_prefix("lower"),
  toupper = sql_prefix("upper"),
  nchar   = sql_prefix("length"),

  `if` = function(cond, if_true, if_false = NULL) {
    build_sql("CASE WHEN ", cond, " THEN ", if_true,
      if (!is.null(if_false)) build_sql(" ELSE "), if_false, " ",
      "END")
  },
  
  `-` = function(x, y = NULL) {
    if (is.null(y)) {
      build_sql(sql(" - "), x)
    } else {
      build_sql(x, sql(" - "), y)
    }
  },
  sql = function(...) sql(...),
  `(` = function(x) {
    build_sql("(", x, ")")
  },
  `{` = function(x) {
    build_sql("(", x, ")")
  },
  desc = function(x) {
    build_sql(x, sql(" DESC"))
  },
  xor = function(x, y) {
    sql(sprintf("%1$s OR %2$s AND NOT (%1$s AND %2$s)", escape(x), escape(y)))
  },
  
  is.null = function(x) {
    build_sql(x, " IS NULL")
  },
  is.na = function(x) {
    build_sql(x, "IS NULL")
  },
  
  as.numeric = function(x) build_sql("CAST(", x, " AS NUMERIC)"),
  as.integer = function(x) build_sql("CAST(", x, " AS INTEGER)"),
  as.character = function(x) build_sql("CAST(", x, " AS TEXT)"),
  
  c = function(...) escape(c(...)),
  `:` = function(from, to) escape(from:to)
)

base_symbols <- sql_translator(
  pi = sql("PI()"),
  `*` = sql("*"),
  `NULL` = sql("NULL")
)

base_agg <- sql_translator(
  # SQL-92 aggregates
  # http://db.apache.org/derby/docs/10.7/ref/rrefsqlj33923.html
  n     = sql_prefix("count"),
  mean  = sql_prefix("avg"),
  var   = sql_prefix("variance"),
  sum   = sql_prefix("sum"),
  min   = sql_prefix("min"),
  max   = sql_prefix("max")
)

base_win <- sql_translator(
  # rank functions have a single order argument that overrides the default
  row_number   = win_rank("row_number"),
  min_rank     = win_rank("rank"),
  rank         = win_rank("rank"),
  dense_rank   = win_rank("dense_rank"),
  percent_rank = win_rank("percent_rank"),
  cume_dist    = win_rank("cume_dist"),
  ntile        = function(order_by, n) {
    over(
      build_sql("NTILE", list(n)), 
      partition_group(), 
      order_by %||% partition_order()
    )
  },
  
  # Recycled aggregate fuctions take single argument, don't need order and 
  # include entire partition in frame.
  mean  = win_recycled("avg"),
  sum   = win_recycled("sum"),
  min   = win_recycled("min"),
  max   = win_recycled("max"),
  n     = function() {
    over(sql("COUNT(*)"), partition_group(), frame = c(-Inf, Inf)) 
  },
  
  # Cumulative function are like recycled aggregates except that R names
  # have cum prefix, order_by is inherited and frame goes from -Inf to 0.
  cummean = win_cumulative("mean"),
  cumsum  = win_cumulative("sum"),
  cummin  = win_cumulative("min"),
  cummax  = win_cumulative("max"),
  
  # Finally there are a few miscellaenous functions that don't follow any
  # particular pattern
  nth_value = function(x, order = NULL) {
    over(build_sql("NTH_VALUE", list(x)), partition_group(), order %||% partition$order())
  },
  first_value = function(x, order = NULL) {
    over(sql("FIRST_VALUE()"), partition_group(), order %||% partition_order())
  },
  last_value = function(x, order = NULL) {
    over(sql("LAST_VALUE()"), partition_group(), order %||% partition_order())
  },
  
  lead = function(x, n = 1L, default = NA, order = NULL) {
    over(
      build_sql("LEAD", list(x, n, default)), 
      partition_group(), 
      order %||% partition_order()
    )
  },
  lag = function(x, n = 1L, default = NA, order = NULL) {
    over(
      build_sql("LAG", list(x, n, default)), 
      partition_group(), 
      order %||% partition_order()
    )
  },
  
  order_by = function(order_by, expr) {
    over(expr, partition_group(), order_by)
  }
)
