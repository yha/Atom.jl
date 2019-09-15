using JuliaInterpreter: root, locals
import ..Atom: wsitem, handle

function contexts(s::DebuggerState = STATE)
  s.frame === nothing && return []
  ctx = []
  trace = ""
  frame = root(s.frame)
  while frame ≠ nothing
    trace = string(trace, "/", frame.framecode.scope isa Method ?
                                frame.framecode.scope.name : "???")
    c = Dict(:context => string("Debug: ", trace), :items => localvars(frame))
    pushfirst!(ctx, c)

    frame = frame.callee
  end
  ctx
end

function localvars(frame)
  vars = locals(frame)
  items = []
  scope = frame.framecode.scope
  mod = scope isa Module ? scope : scope.module
  for v in vars
    # ref: https://github.com/JuliaDebug/JuliaInterpreter.jl/blob/master/src/utils.jl#L365-L370
    v.name == Symbol("#self#") && (isa(v.value, Type) || sizeof(v.value) == 0) && continue
    push!(items, wsitem(mod, v.name, v.value))
  end
  items
end

handle("setStackLevel") do level
  with_error_message() do
    level = level isa String ? parseInt(level) : level
    STATE.level = level
    stepto(active_frame(STATE), level)
    nothing
  end
end
