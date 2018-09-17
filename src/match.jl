import Base: match
using Combinatorics: combinations, permutations

export match


mutable struct Match <: AbstractSet{AbstractDict{Variable,Any}}
    matches::Set{Dict{Variable,Any}}
end
Match(xs::Union{Pair,Dict}...) = Match(Set(Dict.(xs)))
Base.zero(::Type{Match}) = Match()
Base.one(::Type{Match}) = Match(Dict())
Base.length(Θ::Match) = length(Θ.matches)
Base.iterate(Θ::Match) = iterate(Θ.matches)
Base.iterate(Θ::Match, state) = iterate(Θ.matches, state)
Base.push!(Θ::Match, items...) = (push!(Θ.matches, items...); Θ)
Base.copy(Θ::Match) = Match(copy(Θ.matches))
Base.union(Θ₁::Match, Θ₂::Match) = Match(union(Θ₁.matches, Θ₂.matches))
(Θ::Match)(t::Term) = Set{Term}([replace(t, σ) for σ ∈ Θ])

function Base.merge!(Θ::Match, Θs::Match...)
    for Θ′ ∈ Θs
        result = Match()
        for σ′ ∈ Θ′
            foreach(Θ) do σ
                res = copy(σ)
                for (k, v) in σ′
                    if haskey(σ, k)
                        σ[k] == v || return
                    end
                    res[k] = v
                end
                push!(result, res)
            end
        end
        Θ.matches = result
    end
    Θ
end
Base.merge(σ::Match, σs::Match...) = merge!(one(Match), σ, σs...)

"""
    match(pattern::Term, subject::Term) -> Match

Match term `t` to `pattern`, producing a `Match` if the process succeeds.

# Examples
```jldoctest
julia> @vars x;
       @syms a b;

julia> match(@term(x), @term(f(a)))
Match(Set(Dict{Variable,Any}[Dict(x=>:((f)(a)))]))

julia> match(@term(f(x)), @term(a))
Match(Set(Dict{Variable,Any}[]))

julia> match(@term(f(x, x)), @term(f(a, b)))
Match(Set(Dict{Variable,Any}[]))

julia> match(@term(f(x, x)), @term(f(a, a)))
Match(Set(Dict{Variable,Any}[Dict(x=>a)]))
```
"""
match(pattern::Term, subject::Term) = match(Term, get(pattern), get(subject), one(Match))

function match(::Type{Term}, x::Variable, t, Θ)
    image(t) ⊆ image(x) || return zero(Match)
    merge(Θ, Match(x => t))
end
function match(::Type{Term}, p::Expr, s::Expr, Θ)
    p.head === s.head   || return zero(Match)
    image(s) ⊆ image(p) || return zero(Match)

    P = hasproperty(Orderless, s) ? Orderless :
        hasproperty(Flat, s)      ? Flat      :
        Standard
    match(P, p, s, Θ)
end
match(::Type{Term}, p, s, Θ) = (typeof(s) <: typeof(p) && p == s) ? Θ : zero(Match)


function match(::Type{Standard}, f::Expr, g::Expr, Θ)
    length(f.args) == length(g.args) || return zero(Match)

    for (x, y) ∈ zip(f.args, g.args)
        Θ = match(Term, x, y, Θ)
    end

    Θ
end
"""
    match(::Type{Flat}, p::Expr, s::Expr, Θ::Match) -> Match

Match an associative function call to another associative function call, based on the
algorithm by [Krebber](https://arxiv.org/abs/1705.00907). Requires `p` and `s` to have
head `:call`.
"""
function match(::Type{Flat}, p::Expr, s::Expr, Θ)
    p, s = flatten(p), flatten(s)

    @assert p.head === s.head === :call

    pname, pargs = p.args[1], p.args[2:end]
    sname, sargs = s.args[1], s.args[2:end]
    Θ = match(Term, pname, sname, Θ)

    m, n = length(pargs), length(sargs)
    m > n && return zero(Match)
    n_free = n - m
    n_vars = count(x -> x isa Variable, pargs)
    Θᵣ = zero(Match)

    for k ∈ Iterators.product((0:n_free for i ∈ 1:n_vars)...)
        (isempty(k) ? 0 : sum(k)) == n_free || continue  # FIXME: efficiency
        i, j = 1, 1
        Θ′ = Θ
        for pₗ ∈ pargs
            l_sub = 0
            if pₗ isa Variable
                l_sub += k[j]
                j += 1
            end
            s′ = l_sub > 0 ? Expr(:call, pname, sargs[i:i+l_sub]...) : sargs[i]
            Θ′ = match(Term, pₗ, s′, Θ′)
            isempty(Θ′) && break
            i += l_sub + 1
        end
        Θᵣ = Θᵣ ∪ Θ′
    end
    Θᵣ
end
"""
    match(::Type{Orderless}, p::Expr, s::Expr, Θ::Match) -> Match

Match a commutative function call to another commutative function call.
Requires `p` and `s` to have head `:call`.
"""
function match(::Type{Orderless}, p::Expr, s::Expr, Θ)
    @assert p.head === s.head === :call

    matches = map(perms(s)) do fn  # FIXME: efficiency
        P = hasproperty(Flat, s) ? Flat : Standard
        match(P, p, fn, Θ)
    end
    reduce(union, matches)
end
function perms(ex::Expr)
    @assert ex.head === :call

    name, args = ex.args[1], ex.args[2:end]

    map(permutations(args)) do perm
        Expr(:call, name, perm...)
    end |> unique
end
