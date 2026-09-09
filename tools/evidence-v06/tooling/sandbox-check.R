stopifnot(inherits(tryCatch({readLines(url("https://cran.r-project.org", open = "rb"), n = 1); NULL}, error = identity), "error"))
python <- "/usr/bin/python3"
stopifnot(file.exists(python), system2(python, c("-c", shQuote("print(1)"))) != 0L)
cat("External network and Python execution denied by sandbox.\n")
