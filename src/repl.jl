
# FIXME: Should refactor all REPL related functions into a struct that keeps track
#        of global state (terminal size, current prompt, current module etc).
# FIXME: Find a way to reprint what's currently entered in the REPL after changing
#        the module (or delete it in the buffer).

isREPL() = isdefined(Base, :active_repl)

handle("changerepl") do data
  isREPL() || return

  @destruct [prompt || ""] = data
  if !isempty(prompt)
    changeREPLprompt(prompt)
  end
  nothing
end

handle("changemodule") do data
  isREPL() || return

  @destruct [mod || "", cols || 30] = data
  if !isempty(mod)
    parts = split(mod, '.')
    if length(parts) > 1 && parts[1] == "Main"
      shift!(parts)
    end
    if isdebugging()
      changeREPLprompt("debug> ")
    else
      changeREPLmodule(mod)
    end
  end
  nothing
end

current_prompt = "julia> "

function hideprompt(f)
  isREPL() || return f()

  local r
  hidden = false
  didWrite = false
  try
    hidden = changeREPLprompt("")
    r, didWrite = didWriteToREPL(f)
  finally
    if hidden
      didWrite && println()
      changeREPLprompt("julia> ")
    end
  end
  r
end

function didWriteToREPL(f)
  islocked(evallock) && return f(), false

  origout, origerr = STDOUT, STDERR

  rout, wout = redirect_stdout()
  rerr, werr = redirect_stderr()

  outreader = @async begin
    didWrite = false
    while isopen(rout)
      write(origout, readavailable(rout))
      didWrite = true
    end
    didWrite
  end

  errreader = @async begin
    didWrite = false
    while isopen(rerr)
      write(origerr, readavailable(rerr))
      didWrite = true
    end
    didWrite
  end

  local res
  didWriteOut, didWriteErr = false, false

  try
    res = f()
  finally
    redirect_stdout(origout)
    redirect_stderr(origerr)
    close(wout)
    close(werr)
    didWriteOut = wait(outreader)
    didWriteErr = wait(errreader)
  end

  res, didWriteOut || didWriteErr
end


function changeREPLprompt(prompt)
  islocked(evallock) && return false

  global current_prompt = prompt
  repl = Base.active_repl
  main_mode = repl.interface.modes[1]
  main_mode.prompt = prompt
  print("\r       \r")
  print_with_color(:green, prompt, bold = true)
  true
end

function updateworkspace()
  msg("updateWorkspace")
end

function changeREPLmodule(mod)
  islocked(evallock) && return nothing

  mod = getthing(mod)

  repl = Base.active_repl
  main_mode = repl.interface.modes[1]
  main_mode.on_done = Base.REPL.respond(repl, main_mode; pass_empty = false) do line
    if !isempty(line)
      ex = parse(line)
      if isdebugging()
        ret = quote
          Juno.progress(name = "Julia") do p
            try
              lock($evallock)
              Atom.Debugger.interpret($line)
            finally
              Atom.updateworkspace()
              unlock($evallock)
            end
          end
        end
      elseif ex isa Expr && ex.head == :module
        ret = quote
          # eval($mod, Expr(:(=), :ans, Expr(:toplevel, parse($line))))
          Juno.progress(name = "Julia") do p
            try
              lock($evallock)
              eval($mod, Expr(:(=), :ans, Expr(:toplevel, parse($line))))
            finally
              Atom.updateworkspace()
              unlock($evallock)
            end
          end
        end
      else
        ret = quote
          # eval($mod, Expr(:(=), :ans, parse($line)))
          Juno.progress(name = "Julia") do p
            try
              lock($evallock)
              eval($mod, Expr(:(=), :ans, parse($line)))
            finally
              Atom.updateworkspace()
              unlock($evallock)
            end
          end
        end
      end
    else
      ret = :(  )
    end
    return ret
  end
end

function initREPL()

end
