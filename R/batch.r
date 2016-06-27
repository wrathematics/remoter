#' Batch Execution
#' 
#' Run a script on a remote server in batch.  Similar to R's own
#' \code{source()} function.
#' 
#' @param addr
#' The remote host/address/endpoint.
#' @param port
#' The port (number) that will be used for communication between 
#' the client and server.  The port value for the client and server
#' must agree.
#' @param file
#' A character string pointing to the file you wish to execute/source.
#' @param timer
#' Logical; should the "performance prompt", which shows timing
#' statistics after every command, be used?
#' 
#' @return
#' Returns \code{TRUE} invisibly on successful exit.
#' 
#' @export
batch <- function(addr="localhost", port=55555, file, timer=FALSE)
{
  assert_that(is.flag(timer))
  assert_that(is.string(file))
  assert_that(file.exists(file))
  validate_address(addr)
  addr <- scrub_addr(addr)
  validate_port(port, warn=FALSE)
  
  test_connection(addr, port)
  
  reset_state()
  
  set(whoami, "local")
  set(timer, timer)
  set(port, port)
  set(remote_addr, addr)
  
  set(isbatch, TRUE)
  
  remoter_repl_batch(file=file)
  
  invisible(TRUE)
}



remoter_repl_batch <- function(file, env=globalenv())
{
  test <- remoter_init_client()
  if (!test) return(FALSE)
  
  timer <- getval(timer)
  if (timer)
    EVALFUN <- function(expr) capture.output(system.time(expr))
  else
    EVALFUN <- identity
  
  src <- readLines(file)
  len <- length(src)
  line <- 1L
  
  while (TRUE)
  {
    input <- character(0)
    set.status(continuation, FALSE)
    set.status(visible, FALSE)
    
    while (TRUE)
    {
      tmp <- src[line]
      
      if (gsub(tmp, pattern=" +", replacement="") == "")
      {
        line <- line + 1L
        next
      }
      
      input <- c(input, src[line])
      
      timing <- EVALFUN({
        remoter_client_send(input=input)
      })
      
      if (get.status(continuation))
      {
        line <- line + 1L
        next
      }
      
      if (timer)
      {
        cat("## ")
        cat(input)
        cat("\n")
      }
      
      remoter_repl_printer()
      
      if (timer)
      {
        cat(paste0(timing[-1], collapse="\n"), "\n\n")
      }
      
      break
    }
    
    line <- line + 1L
    
    if (line > len)
      break
  }
  
  set.status(remoter_prompt_active, FALSE)
  set.status(should_exit, FALSE)
  
  return(invisible())
}