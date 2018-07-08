module SymReduce

export Patterns, @term, normalize


include("patterns/Patterns.jl")
using .Patterns

include("rules.jl")


normalize(trs::TermRewritingSystem) = Base.Fix2(normalize, trs)
normalize(::Term, ::R) where {R<:Rule} = error("normalize undefined for rule type $R")
normalize(t::Term, set::Symbol) = normalize(t, rules(set))
function normalize(t::Term, trs::TermRewritingSystem)
    while true
        t = map(normalize(trs), t)
        t′ = foldl(normalize, t, trs)
        t == t′ && return t
        t = t′
    end
end
normalize(t::Term) = normalize(t, rules())

end # module
