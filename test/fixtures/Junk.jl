module Junk

export imnotdefined

function useme(args)
    @info "then you're sane"
end

macro immacro(expr)
    quote
        @warn "You shouldn't use me in most your use cases"
    end
end

module Junk2 end

const toplevelval = "you should jump to me !"

# mock overloaded method
struct JunkType end
Base.isconst(::JunkType) = false

"""im a doc"""
const imwithdoc = nothing

end

baremodule BareJunk

"""im a doc"""
const imwithdoc = nothing

end
