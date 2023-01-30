abstract type AbstractElement end

const AVOGADRO_CONSTANT = 6.02214179e23u"mol^-1"

Base.@kwdef struct Selenium75 <: AbstractElement
    "Molar Mass [g / mol]"
    M::typeof(1.0g*mol^-1) = 78.971g*mol^-1
    "Half life time [second]"
    tₕ::Unitful.Time = 10.3491e6s
    ρ::typeof(1.0kg/m^3) = 4.79u"g/cm^3"
end

molar_mass(elem::AbstractElement)::Float64 = ustrip(upreferred(elem.M))
half_life(elem::AbstractElement)::Float64  = ustrip(upreferred(elem.tₕ))
density(elem::AbstractElement)::Float64  = ustrip(upreferred(elem.ρ))

Base.@kwdef struct Activity{T <: AbstractElement}
    element::T = Selenium75()
    A::typeof(1.0Bq) = 1.49e10Bq
end

Activity(el::AbstractElement, A::Number) = Activity(el, A * Bq)

function get_mass(activity::Activity) 
    mass = activity.A * activity.element.M * activity.element.tₕ / (AVOGADRO_CONSTANT * log(2))
    uconvert(g, mass)
end