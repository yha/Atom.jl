global sock = nothing

isactive(sock::Void) = false
isactive(sock) = isopen(sock)

macro ierrs(ex)
  :(try
      $(ex)
    catch e
      msg("error", @d(:msg=>"Julia Client – Internal Error",
                      :detail=>sprint(showerror, e, catch_backtrace()),
                      :dismissable=>true))
    end)
end

function initialise()
  exit_on_sigint(false)
  eval(AtomShell, :(_shell = $(Shell())))
end

function connect(port)
  global sock = Base.connect(port)
  @async while isopen(sock)
    @ierrs let # Don't let tasks close over the same t, data
      msg = JSON.parse(sock)
      @schedule @ierrs handlemsg(msg...)
    end
  end
  initialise()
end

function msg(t, args...)
  isactive(sock) || return
  println(sock, json(c(t, args...)))
end

const handlers = Dict{UTF8String, Function}()

handle(f, t) = handlers[t] = f

id = 0
const callbacks = Dict{Int,Condition}()

function rpc(t, args...)
  i, c = (global id += 1), Condition()
  callbacks[i] = c
  msg(d(:type => t, :callback => i), args...)
  return wait(c)
end

function handlemsg(t, args...)
  callback = nothing
  isa(t, Associative) && ((t, callback) = (t["type"], t["callback"]))
  if haskey(handlers, t)
    result = handlers[t](args...)
    isa(callback, Integer) && msg(callback, result)
  elseif haskey(callbacks, t)
    @assert length(args) == 1
    notify(callbacks[t], args[1])
    delete!(callbacks, t)
  else
    warn("Atom.jl: unrecognised message $t.")
  end
end

isconnected() = sock ≠ nothing && isopen(sock)
