export Property
export Flat, Orderless


abstract type Property end

struct Flat <: Property end
struct Orderless <: Property end


property(::Type{<:Property}, x) = nothing
hasproperty(P::Type{<:Property}, x) = property(P, x) !== nothing